// End-to-end ANONYMOUS guest shopping on a real simulator against the real
// local backend (Forever-API :8989 started with the DEV-ONLY fake Bakong on
// :9099). Run with:
//   flutter test integration_test/guest_checkout_test.dart -d <device-id>
//
// Guests are anonymous cart sessions (`X-Guest-Session`), never a login:
// `currentUserProvider` stays null the whole time.
//
// Test 1: fresh launch + opening the Cart tab create NO guest session ->
//   product page (sold-out size disabled; a 409 OUT_OF_STOCK add, which is
//   also what lazily creates the session) -> add 2 -> APP RESTART (new
//   ProviderContainer + storage loaded from the same keychain) -> the cart is
//   still there, still logged out, Profile shows the logged-out state.
// Test 2 (KHQR, same guest session): cart quantity 3 -> checkout with an
//   EMPTY form filled by the test -> KHQR double-tapped -> pending, nothing
//   claims success -> customer "pays" via fake Bakong -> paid -> the guest
//   confirmation (in-memory access token) shows "Paid". Server: exactly one
//   order, guest=true, userId=null.
// Test 3 (COD, same session): quick add -> checkout (empty form) -> pay on
//   delivery confirmation, guest order, userId=null.
//
// Guest sessions are rate limited (20/hour per IP): this file starts ONE.
// Order ids are printed as `IT_GUEST_ORDER kind=<id>` for the DB check.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/utils/formatters.dart';
import 'package:forever_app/core/widgets/choice_chip_pill.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/auth/presentation/screens/login_screen.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/guest_session_providers.dart';
import 'package:forever_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:forever_app/features/orders/domain/entities/order.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:forever_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:forever_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:forever_app/features/orders/presentation/widgets/khqr_payment_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

late Dio admin;
late Map<String, dynamic> product; // the product under test (public JSON)
late String soldOutSize;
late String buySize;
int? originalStock;
int? originalBuyStock;
final runTag = DateTime.now().millisecondsSinceEpoch;

/// Admin view of the orders placed with [email] (includes unpaid KHQR).
Future<List<Map<String, dynamic>>> ordersByEmail(String email) async {
  final res = (await admin.get<Map<String, dynamic>>(
    '/api/admin/orders',
    queryParameters: {'q': email, 'size': 50},
  )).data!;
  return (res['content'] as List)
      .cast<Map<String, dynamic>>()
      .where((o) => (o['address'] as Map)['email'] == email)
      .toList();
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    admin = await adminDio();
    // A product nobody else is likely to be poking at: active, >= 2 sizes,
    // every size with plenty of stock (so the test is not order-dependent).
    final page = (await Dio().get<Map<String, dynamic>>(
      '$apiBase/api/products',
      queryParameters: {'size': 60},
    )).data!;
    final candidates = (page['content'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (p) =>
              p['inStock'] == true &&
              (p['sizes'] as List).length >= 2 &&
              (p['stock'] as Map).values.every((v) => (v as num) >= 5),
        )
        .toList();
    expect(candidates, isNotEmpty, reason: 'no suitable seeded product');
    product = candidates[candidates.length ~/ 2];
    final sizes = (product['sizes'] as List).cast<String>();
    soldOutSize = sizes.first;
    buySize = sizes[1];
    originalStock = await setStock(admin, product['id'] as int, soldOutSize, 0);
  });

  tearDownAll(() async {
    if (originalStock != null) {
      await setStock(admin, product['id'] as int, soldOutSize, originalStock!);
    }
    if (originalBuyStock != null) {
      await setStock(admin, product['id'] as int, buySize, originalBuyStock!);
    }
  });

  testWidgets('guest: no session until add-to-cart; cart survives a restart; '
      'never logged in', (tester) async {
    final id = product['id'] as int;

    await launchApp(tester, fresh: true);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(LoginScreen), findsNothing);
    var container = appContainer(tester);
    expect(container.read(currentUserProvider), isNull);
    expect(await storedGuestToken(), isNull);

    // Opening the Cart tab must not start a guest session.
    routerOf(tester).go('/cart');
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(container.read(guestSessionProvider), isNull);
    expect(await storedGuestToken(), isNull, reason: 'Cart tab: no session');

    // Open the product.
    routerOf(tester).push('/product/$id');
    // Wait for the real product, not the skeleton placeholder (which also
    // renders size chips).
    await pumpUntil(tester, find.text(product['name'] as String));
    await pumpUntil(tester, find.byKey(Key('size-$buySize')));
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(await storedGuestToken(), isNull, reason: 'browsing: no session');

    // The sold-out size is shown but disabled; tapping it selects nothing.
    final soldOut = find.byKey(Key('size-$soldOutSize'));
    expect(soldOut, findsOneWidget);
    expect(tester.widget<PillChip>(soldOut).enabled, isFalse);
    await tester.tap(soldOut, warnIfMissed: false);
    await tester.pump();
    expect(tester.widget<PillChip>(soldOut).selected, isFalse);

    // Pick an in-stock size and quantity 2.
    await tester.tap(find.byKey(Key('size-$buySize')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('qty-inc')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('qty-value'))).data, '2');

    // Stock drops to 1 while the shopper is on the page: the add is refused
    // with the API's 409 OUT_OF_STOCK message, and the page refreshes to the
    // real stock. This first add is what lazily creates the guest session.
    originalBuyStock = await setStock(admin, id, buySize, 1);
    await tester.tap(find.text('Add to cart'));
    await pumpUntil(tester, find.textContaining('Only 1 left of'));
    await pumpUntil(tester, find.text('Only 1 left'));
    expect(tester.widget<Text>(find.byKey(const Key('qty-value'))).data, '1');
    expect(container.read(cartCountProvider), 0);
    final guestToken = await storedGuestToken();
    expect(guestToken, isNotNull, reason: 'first add-to-cart starts it');
    expect(container.read(currentUserProvider), isNull, reason: 'not a login');
    await setStock(admin, id, buySize, originalBuyStock!);
    originalBuyStock = null;
    await waitForSnackbars(tester);

    // Reopen the page to pick up the restored stock, then quantity 2 again.
    await tester.tap(find.byTooltip('Back'));
    await pumpFor(tester, const Duration(seconds: 1));
    routerOf(tester).push('/product/$id');
    await pumpUntil(tester, find.text(product['name'] as String));
    await pumpUntil(tester, find.byKey(Key('size-$buySize')));
    await tester.tap(find.byKey(Key('size-$buySize')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('qty-inc')));
    await tester.pump();
    await tester.tap(find.text('Add to cart'));
    await pumpUntil(tester, find.textContaining('Added 2 ×'));
    expect(container.read(cartCountProvider), 2);
    expect(await storedGuestToken(), guestToken, reason: 'same session');
    expect(container.read(currentUserProvider), isNull);
    await waitForSnackbars(tester);

    // ---- App restart: new container, storage re-read from the keychain.
    await launchApp(tester);
    await pumpFor(tester, const Duration(seconds: 2));
    container = appContainer(tester);
    await container.read(authControllerProvider.future);
    expect(container.read(currentUserProvider), isNull);
    expect(container.read(guestSessionProvider), guestToken);
    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.single.productId, id);
    expect(cart.items.single.quantity, 2);
    routerOf(tester).go('/cart');
    await pumpUntil(tester, find.byKey(Key('cart-line-$id-$buySize')));

    // Profile: logged-out state, no account entries.
    routerOf(tester).go('/profile');
    await pumpUntil(tester, find.byKey(const Key('profile-logged-out')));
    expect(find.text('My orders'), findsNothing);
    expect(find.text('My wishlist'), findsNothing);
    expect(find.text('My addresses'), findsNothing);
    expect(find.text('Log out'), findsNothing);
    expect(container.read(currentUserProvider), isNull);
    await pumpFor(tester, const Duration(seconds: 1)); // screenshot window
  });

  testWidgets('guest KHQR checkout: empty form, pending until PAID, '
      'confirmation via in-memory access token', (tester) async {
    final id = product['id'] as int;
    final price = (product['price'] as num).toDouble();
    final email = 'it.khqr.$runTag@example.com';

    await launchApp(tester); // same guest session (stored token)
    await pumpFor(tester, const Duration(seconds: 2));
    final container = appContainer(tester);
    expect(container.read(currentUserProvider), isNull);

    routerOf(tester).go('/cart');
    final line = find.byKey(Key('cart-line-$id-$buySize'));
    await pumpUntil(tester, line);
    final cartLine = container.read(cartControllerProvider).value!.items.single;
    expect(cartLine.quantity, 2);
    expect(find.text(formatPrice(price * 2)), findsWidgets);

    // Change the quantity to 3 from the cart.
    await tester.tap(find.byKey(Key('line-${cartLine.id}-inc')));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == Key('line-subtotal-${cartLine.id}') &&
            w.data == formatPrice(price * 3),
      ),
      reason: 'line subtotal to become 3 × price',
    );

    await waitForSnackbars(tester);
    await tester.tap(find.text('Checkout'));
    await pumpUntil(tester, find.byType(CheckoutScreen));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Save this address for next time'), findsNothing);
    // Starts EMPTY (asserted per field), then the shopper types real details.
    await fillCheckout(tester, email: email, lastName: 'KHQR');

    await tester.ensureVisible(find.text('KHQR'));
    await tester.tap(find.text('KHQR'));
    await tester.pump();
    final pay = find.text('Pay with KHQR');
    await tester.ensureVisible(pay);
    await tester.pump();
    // Double tap: must still create exactly one order.
    await tester.tap(pay);
    await tester.tap(pay, warnIfMissed: false);

    await pumpUntil(tester, find.byType(KhqrPaymentSheet));
    final payment = tester
        .widget<KhqrPaymentSheet>(find.byType(KhqrPaymentSheet))
        .payment;
    debugPrint('IT_GUEST_ORDER khqr=${payment.orderId}');
    expect(payment.qrString, isNotNull);
    expect(payment.guestAccessToken, isNotNull);
    expect(
      container.read(guestOrderAccessProvider)[payment.orderId],
      payment.guestAccessToken,
    );
    expect(find.byKey(const Key('khqr-pending')), findsOneWidget);
    // While pending, NOTHING claims success.
    await pumpFor(tester, const Duration(seconds: 4)); // >= 1 verify poll
    expect(find.byKey(const Key('khqr-paid')), findsNothing);
    expect(find.textContaining('Payment received'), findsNothing);
    expect(find.byType(OrderDetailScreen), findsNothing);

    // Server-side: exactly ONE order despite the double tap, unpaid, and a
    // guest order (no account).
    var all = await ordersByEmail(email);
    expect(all, hasLength(1), reason: 'double tap must not duplicate');
    expect(all.single['id'], payment.orderId);
    expect(all.single['paid'], isFalse);
    expect(all.single['userId'], isNull);
    final repo = container.read(orderRepositoryProvider);
    final pending = await repo.getGuestOrder(
      payment.orderId,
      payment.guestAccessToken!,
    );
    expect(pending.paymentState, PaymentState.awaitingPayment);
    expect(pending.guest, isTrue);
    expect(pending.total, closeTo(payment.amount, 0.001));

    // The customer pays the QR in their banking app (fake Bakong, dev only).
    await payQr(payment.qrString!, payment.amount);

    await pumpUntil(
      tester,
      find.byKey(const Key('khqr-paid')),
      timeout: const Duration(seconds: 20),
    );
    await pumpUntil(tester, find.byType(OrderDetailScreen));
    expect(
      find.textContaining('Payment received — order #${payment.orderId}'),
      findsOneWidget,
    );
    // The confirmation is the guest route, readable via the in-memory token.
    expect(
      routerOf(tester).routeInformationProvider.value.uri.path,
      '/guest-order/${payment.orderId}',
    );
    await pumpUntil(
      tester,
      find.byKey(Key('payment-state-${payment.orderId}')),
    );
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Order #${payment.orderId}'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 2)); // screenshot window

    all = await ordersByEmail(email);
    expect(all, hasLength(1));
    expect(all.single['paid'], isTrue);
    expect(all.single['userId'], isNull);
    expect(all.single['paymentMethod'], 'KHQR');
    expect((all.single['items'] as List).single['quantity'], 3);
    // The access token is never persisted on the device.
    final keychain = await const FlutterSecureStorage().readAll();
    expect(keychain.values, isNot(contains(payment.guestAccessToken)));
    expect(container.read(currentUserProvider), isNull);
  });

  testWidgets('guest quick add, then cash on delivery (empty form)', (
    tester,
  ) async {
    final email = 'it.cod.$runTag@example.com';
    await launchApp(tester); // same guest session
    await pumpUntil(tester, byKeyPrefix('quick-add-'));
    final container = appContainer(tester);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(container.read(currentUserProvider), isNull);
    final token = container.read(guestSessionProvider);
    expect(token, isNotNull);
    await container.read(cartControllerProvider.future);
    final countBefore = container.read(cartCountProvider);

    final quickAdd = byKeyPrefix('quick-add-').first;
    await tester.ensureVisible(quickAdd);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(quickAdd);
    await pumpUntil(tester, find.byKey(const Key('quick-add-sheet')));
    expect(find.byType(ProductDetailScreen), findsNothing);

    await pumpFor(tester, const Duration(seconds: 1)); // fresh stock loads
    final enabled = byKeyPrefix(
      'quick-size-',
    ).evaluate().map((e) => e.widget as PillChip).firstWhere((c) => c.enabled);
    await tester.tap(find.byWidget(enabled));
    await tester.pump();
    await tester.tap(find.textContaining('Add to cart ·'));
    await pumpUntil(tester, find.text('Added to cart'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(container.read(cartCountProvider), countBefore + 1);
    expect(container.read(guestSessionProvider), token, reason: 'no new one');
    expect(container.read(currentUserProvider), isNull);

    routerOf(tester).go('/cart');
    await pumpUntil(tester, find.text('Checkout'));
    await waitForSnackbars(tester);
    await tester.tap(find.text('Checkout'));
    await pumpUntil(tester, find.byType(CheckoutScreen));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await fillCheckout(tester, email: email, lastName: 'COD');
    final place = find.text('Place order');
    await tester.scrollUntilVisible(
      place,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CheckoutScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(place);
    await pumpUntil(tester, find.byType(OrderDetailScreen));
    expect(find.textContaining('pay in cash on delivery'), findsOneWidget);
    final placed = await ordersByEmail(email);
    expect(placed, hasLength(1));
    final cod = placed.single;
    debugPrint('IT_GUEST_ORDER cod=${cod['id']}');
    expect(cod['paymentMethod'], 'COD');
    expect(cod['paid'], isFalse);
    expect(cod['userId'], isNull);
    expect(container.read(guestOrderAccessProvider), contains(cod['id']));
    await pumpUntil(tester, find.byKey(Key('payment-state-${cod['id']}')));
    expect(find.text('Pay on delivery'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
    expect(container.read(cartCountProvider), countBefore); // bought line gone
    await pumpFor(tester, const Duration(seconds: 2)); // screenshot window

    // After an app restart the confirmation is no longer reachable in-app
    // (the access token was memory-only): "check your email".
    await launchApp(tester);
    await pumpFor(tester, const Duration(seconds: 2));
    routerOf(tester).push('/guest-order/${cod['id']}');
    await pumpUntil(tester, find.byKey(const Key('guest-order-unavailable')));
    expect(find.text('Check your email'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 1)); // screenshot window
  });
}
