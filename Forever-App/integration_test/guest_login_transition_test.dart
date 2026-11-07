// Guest -> login -> logout on the real simulator against the real API.
//   flutter test integration_test/guest_login_transition_test.dart -d <sim> \
//     --dart-define=IT_USER_EMAIL=<verified user> \
//     --dart-define=IT_USER_PASSWORD=<password>
//
// A guest places a COD order with e-mail X and then has item A in the cart.
// They log in as the REGISTERED customer whose e-mail is also X:
//  * the cart shows ONLY the account's own cart (item B), not A — no merge;
//  * "My orders" does not contain the guest order — no attaching by e-mail;
//  * the guest session was revoked server-side (GET /api/cart with the old
//    X-Guest-Session -> 401 GUEST_SESSION_EXPIRED) and deleted locally;
// then they log out: empty cart, logged-out Profile, no guest session.
// Prints `IT_GUEST_ORDER transition=<id>` for the DB check (user_id null).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/widgets/choice_chip_pill.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/auth/presentation/screens/login_screen.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/guest_session_providers.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:forever_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:forever_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:forever_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

const userEmail = String.fromEnvironment('IT_USER_EMAIL');
const userPassword = String.fromEnvironment(
  'IT_USER_PASSWORD',
  defaultValue: 'Password123',
);

late Dio account; // the registered customer, for setup/cleanup only
late Map<String, dynamic> productA;
late Map<String, dynamic> productB;

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> clearAccountCart() async {
  final cart = (await account.get<Map<String, dynamic>>('/api/cart')).data!;
  for (final line in (cart['items'] as List).cast<Map<String, dynamic>>()) {
    await account.delete<void>('/api/cart/items/${line['id']}');
  }
}

String firstSizeWithStock(Map<String, dynamic> p) => (p['sizes'] as List)
    .cast<String>()
    .firstWhere((s) => ((p['stock'] as Map)[s] as num) >= 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(userEmail, isNotEmpty, reason: 'pass --dart-define=IT_USER_EMAIL');
    account = Dio(BaseOptions(baseUrl: apiBase));
    final login = await account.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': userEmail, 'password': userPassword},
    );
    account.options.headers['Authorization'] =
        'Bearer ${login.data!['accessToken']}';
    final page = (await Dio().get<Map<String, dynamic>>(
      '$apiBase/api/products',
      queryParameters: {'size': 60},
    )).data!;
    final buyable = (page['content'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (p) =>
              p['inStock'] == true &&
              (p['stock'] as Map).values.any((v) => (v as num) >= 3),
        )
        .toList();
    productA = buyable.first;
    productB = buyable.last;
    expect(productA['id'], isNot(productB['id']));
    // The account's own cart: exactly item B.
    await clearAccountCart();
    await account.post<void>(
      '/api/cart/items',
      data: {
        'productId': productB['id'],
        'size': firstSizeWithStock(productB),
        'quantity': 1,
      },
    );
  });

  tearDownAll(() async {
    await clearAccountCart();
  });

  Future<void> addAToCart(WidgetTester tester) async {
    final id = productA['id'] as int;
    final size = firstSizeWithStock(productA);
    routerOf(tester).push('/product/$id');
    await pumpUntil(tester, find.text(productA['name'] as String));
    await pumpUntil(tester, find.byKey(Key('size-$size')));
    final chip = find.byKey(Key('size-$size'));
    if (!tester.widget<PillChip>(chip).selected) {
      await tester.tap(chip);
      await tester.pump();
    }
    await tester.tap(find.text('Add to cart'));
    await pumpUntil(tester, find.text('Added to cart'));
    await waitForSnackbars(tester);
  }

  testWidgets('guest order + cart A -> log in as X: account cart only, no '
      'guest order in My orders, guest session revoked -> log out', (
    tester,
  ) async {
    await launchApp(tester, fresh: true);
    await pumpFor(tester, const Duration(seconds: 2));
    final container = appContainer(tester);
    expect(container.read(currentUserProvider), isNull);

    // ---- As a guest: buy A with e-mail X (cash on delivery).
    await addAToCart(tester);
    final guestToken = await storedGuestToken();
    expect(guestToken, isNotNull);
    routerOf(tester).go('/cart');
    await pumpUntil(tester, find.text('Checkout'));
    await tester.tap(find.text('Checkout'));
    await pumpUntil(tester, find.byType(CheckoutScreen));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await fillCheckout(tester, email: userEmail, lastName: 'Transition');
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
    final guestOrderId = container.read(guestOrderAccessProvider).keys.single;
    debugPrint('IT_GUEST_ORDER transition=$guestOrderId');
    await waitForSnackbars(tester);

    // ...and A is in the guest cart again at login time.
    await addAToCart(tester);
    expect(
      container
          .read(cartControllerProvider)
          .value!
          .items
          .map((l) => l.productId),
      [productA['id']],
    );
    expect(container.read(currentUserProvider), isNull);

    // ---- Log in through the real login screen.
    routerOf(tester).go('/profile');
    await pumpUntil(tester, find.byKey(const Key('profile-logged-out')));
    await tester.tap(find.text('Log in'));
    await pumpUntil(tester, find.byType(LoginScreen));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), userEmail);
    await tester.enterText(fields.at(1), userPassword);
    await tester.tap(find.text('Log in').last);
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (container.read(currentUserProvider) == null &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(container.read(currentUserProvider)?.email, userEmail);

    // Guest session: deleted locally and revoked server-side.
    expect(container.read(guestSessionProvider), isNull);
    expect(await storedGuestToken(), isNull);
    final probe = await plainDio().get<Object?>(
      '/api/cart',
      options: Options(headers: {'X-Guest-Session': guestToken}),
    );
    expect(probe.statusCode, 401);
    expect((probe.data! as Map)['code'], 'GUEST_SESSION_EXPIRED');

    // Cart: ONLY the account's item B — A was not merged in.
    final cart = await container.read(cartControllerProvider.future);
    expect(cart.items.map((l) => l.productId), [productB['id']]);
    routerOf(tester).go('/cart');
    await pumpUntil(tester, byKeyPrefix('cart-line-${productB['id']}-'));
    expect(byKeyPrefix('cart-line-${productA['id']}-'), findsNothing);

    // My orders: the guest order (same e-mail!) is NOT attached.
    routerOf(tester).push('/orders');
    await pumpUntil(tester, find.byType(OrdersScreen));
    await pumpFor(tester, const Duration(seconds: 2));
    final mine = await container.read(ordersControllerProvider.future);
    expect(mine.map((o) => o.id), isNot(contains(guestOrderId)));
    expect(find.textContaining('#$guestOrderId'), findsNothing);
    expect(container.read(guestOrderAccessProvider), isEmpty);
    await pumpFor(tester, const Duration(seconds: 1)); // screenshot window

    // ---- Log out: a fresh anonymous visitor with an empty cart.
    routerOf(tester).go('/profile');
    await pumpUntil(tester, find.text('Log out'));
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await pumpUntil(tester, find.byKey(const Key('profile-logged-out')));
    expect(container.read(currentUserProvider), isNull);
    expect(find.text('My orders'), findsNothing);
    final after = await container.read(cartControllerProvider.future);
    expect(after.isEmpty, isTrue);
    expect(container.read(cartCountProvider), 0);
    expect(await storedGuestToken(), isNull);
    routerOf(tester).go('/cart');
    await pumpUntil(tester, find.text('Your cart is empty'));
  });
}
