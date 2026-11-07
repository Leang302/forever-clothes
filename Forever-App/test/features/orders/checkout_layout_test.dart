// Regression test for FIX-004: building CheckoutScreen under the real app
// theme used to throw "BoxConstraints forces an infinite width" /
// "RenderBox was not laid out" from the coupon row's OutlinedButton.
//
// Root cause: AppTheme's outlined/filled button themes used
// `minimumSize: Size.fromHeight(54)`, i.e. a minimum WIDTH of
// double.infinity. A Row gives its non-flexible children unbounded width, so
// a themed button placed directly in a Row (the coupon "Apply" button) is
// asked to be at least infinitely wide — an unsatisfiable constraint.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/app/theme/app_theme.dart';
import 'package:forever_app/core/error/app_exception.dart';
import 'package:forever_app/core/storage/guest_session_storage.dart';
import 'package:forever_app/core/storage/storage_providers.dart';
import 'package:forever_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:forever_app/features/addresses/presentation/providers/address_providers.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/orders/domain/entities/order.dart';
import 'package:forever_app/features/orders/domain/repositories/order_repository.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:forever_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class _MockCart extends Mock implements CartRepository {}

class _MockOrders extends Mock implements OrderRepository {}

class _MockAddresses extends Mock implements AddressRepository {}

/// An anonymous shopper who already added to cart (has a guest cart session).
class _GuestWithCart extends GuestSessionStorage {
  @override
  String? get token => 'guest-session';
}

const _user = AppUser(id: 1, name: 'Test Shopper', email: 't@example.com');
const _cart = Cart(
  items: [
    CartLine(
      id: 1,
      productId: 1,
      name: 'Tee',
      price: 100,
      size: 'M',
      quantity: 1,
      stock: 10,
    ),
  ],
  itemCount: 1,
  subtotal: 100,
  deliveryFee: 10,
  total: 110,
);

void main() {
  // No network in widget tests: render with fallback fonts instead of trying
  // to download Outfit/Prata (the theme itself is what's under test).
  GoogleFonts.config.allowRuntimeFetching = false;

  late _MockCart cart;
  late _MockOrders orders;
  late _MockAddresses addresses;

  setUpAll(() {
    registerFallbackValue(PaymentMethod.cod);
    registerFallbackValue(
      const ShippingAddress(
        firstName: '',
        lastName: '',
        email: '',
        street: '',
        city: '',
        state: '',
        zipcode: '',
        country: '',
        phone: '',
      ),
    );
  });

  setUp(() {
    cart = _MockCart();
    orders = _MockOrders();
    addresses = _MockAddresses();
    when(() => cart.getCart()).thenAnswer((_) async => _cart);
    when(() => addresses.list()).thenAnswer((_) async => const []);
    when(() => orders.checkoutOptions()).thenAnswer(
      (_) async => const [
        ShippingOption(
          code: 'STANDARD',
          name: 'Standard',
          fee: 10,
          estimate: '3-5 days',
        ),
      ],
    );
  });

  Future<void> pumpCheckout(
    WidgetTester tester, {
    AppUser? user = _user,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          currentUserProvider.overrideWithValue(user),
          guestSessionStorageProvider.overrideWithValue(_GuestWithCart()),
          cartRepositoryProvider.overrideWithValue(cart),
          orderRepositoryProvider.overrideWithValue(orders),
          addressRepositoryProvider.overrideWithValue(addresses),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CheckoutScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('CheckoutScreen lays out under the app theme without errors', (
    tester,
  ) async {
    await pumpCheckout(tester);
    expect(tester.takeException(), isNull);

    // Scroll the coupon row into view so it is actually laid out and painted.
    await tester.scrollUntilVisible(
      find.text('Apply'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final apply = find.ancestor(
      of: find.text('Apply'),
      matching: find.byType(OutlinedButton),
    );
    expect(apply, findsOneWidget);
    final size = tester.getSize(apply);
    expect(size.width.isFinite, isTrue);
    expect(size.width, lessThan(200), reason: 'Apply must not be full width');
    expect(size.height, 56);
  });

  testWidgets('themed buttons placed directly in a Row get a finite size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              FilledButton(onPressed: () {}, child: const Text('Filled')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(OutlinedButton)).width.isFinite, isTrue);
    expect(tester.getSize(find.byType(FilledButton)).width.isFinite, isTrue);
  });

  group('guest checkout form', () {
    Future<void> pumpGuest(WidgetTester tester) =>
        pumpCheckout(tester, user: null);

    const addressLabels = [
      'First name',
      'Last name',
      'Email',
      'Street address',
      'City',
      'State / province',
      'Zip code',
      'Country',
      'Phone number',
    ];

    String textOf(WidgetTester tester, String label) => tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, label))
        .controller!
        .text;

    testWidgets('a guest starts from an EMPTY form: no generated or fake '
        'details, no saved addresses, no "save address"', (tester) async {
      await pumpGuest(tester);
      for (final label in addressLabels) {
        final field = find.widgetWithText(TextFormField, label);
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(textOf(tester, label), isEmpty, reason: label);
      }
      expect(find.text('Save this address for next time'), findsNothing);
      verifyNever(() => addresses.list());
    });

    testWidgets('a registered customer keeps the profile prefill', (
      tester,
    ) async {
      await pumpCheckout(tester);
      expect(textOf(tester, 'First name'), 'Test');
      expect(textOf(tester, 'Last name'), 'Shopper');
      expect(textOf(tester, 'Email'), 't@example.com');
      expect(find.text('Save this address for next time'), findsOneWidget);
    });

    testWidgets('empty or invalid details are refused before any request', (
      tester,
    ) async {
      await pumpGuest(tester);
      await tester.scrollUntilVisible(
        find.text('Place order'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Place order'));
      await tester.pump();
      verifyNever(
        () => orders.place(
          address: any(named: 'address'),
          paymentMethod: any(named: 'paymentMethod'),
          couponCode: any(named: 'couponCode'),
          shippingMethod: any(named: 'shippingMethod'),
          cartItemIds: any(named: 'cartItemIds'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'First name'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Required'), findsWidgets);
    });

    test('field rules', () {
      expect(checkoutFieldError('  '), 'Required');
      expect(checkoutFieldError('Tola'), isNull);
      expect(checkoutFieldError('a' * 81, max: 80), isNotNull);
      expect(checkoutFieldError('not-an-email', email: true), isNotNull);
      expect(checkoutFieldError('a@b', email: true), isNotNull);
      expect(checkoutFieldError('tola@example.com', email: true), isNull);
      expect(checkoutFieldError('012', phone: true), isNotNull);
      expect(checkoutFieldError('call me', phone: true), isNotNull);
      expect(checkoutFieldError('012 345 678', phone: true), isNull);
      expect(checkoutFieldError('+855 12-345-678', phone: true), isNull);
    });
  });

  group('idempotency key', () {
    Future<void> fill(WidgetTester tester) async {
      Future<void> f(String label, String v) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(field, v);
      }

      await f('First name', 'Test');
      await f('Last name', 'Shopper');
      await f('Email', 't@example.com');
      await f('Street address', '1 Main');
      await f('City', 'PP');
      await f('State / province', 'PP');
      await f('Zip code', '12000');
      await f('Country', 'KH');
      await f('Phone number', '012 345 678');
      await tester.pump();
    }

    Future<void> tapPlace(WidgetTester tester) async {
      // A previous error snackbar floats over the bottom of the page.
      ScaffoldMessenger.of(
        tester.element(find.byType(CheckoutScreen)),
      ).removeCurrentSnackBar();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Place order'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Place order'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    List<String?> sentKeys() => verify(
      () => orders.place(
        address: any(named: 'address'),
        paymentMethod: any(named: 'paymentMethod'),
        couponCode: any(named: 'couponCode'),
        shippingMethod: any(named: 'shippingMethod'),
        cartItemIds: any(named: 'cartItemIds'),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured.cast<String?>();

    testWidgets('identical retry reuses the key; changed details get a new '
        'one; 409 IDEMPOTENCY_KEY_MISMATCH is explained', (tester) async {
      var calls = 0;
      when(
        () => orders.place(
          address: any(named: 'address'),
          paymentMethod: any(named: 'paymentMethod'),
          couponCode: any(named: 'couponCode'),
          shippingMethod: any(named: 'shippingMethod'),
          cartItemIds: any(named: 'cartItemIds'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 3) {
          throw const AppException(
            'Idempotency key was already used for a different order',
            code: 'IDEMPOTENCY_KEY_MISMATCH',
            statusCode: 409,
          );
        }
        throw const AppException('Cannot reach the server.', code: 'NETWORK');
      });

      await pumpCheckout(tester);
      await fill(tester);
      await tapPlace(tester); // 1: times out
      await tapPlace(tester); // 2: identical retry
      // Scroll back up and change only the street.
      final street = find.widgetWithText(TextFormField, 'Street address');
      await tester.scrollUntilVisible(
        street,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(street, '2 Other St');
      await tester.pump();
      await tapPlace(tester); // 3: details changed -> new key (server: 409)
      await tester.pump(
        const Duration(seconds: 1),
      ); // previous snackbar hides first
      expect(
        find.textContaining('Your checkout details changed'),
        findsOneWidget,
      );
      await tapPlace(tester); // 4: after a mismatch -> yet another key

      final keys = sentKeys();
      expect(keys, hasLength(4));
      expect(keys.every((k) => k != null && k.length == 32), isTrue);
      expect(keys[1], keys[0], reason: 'identical retry keeps the key');
      expect(keys[2], isNot(keys[1]), reason: 'changed details: new key');
      expect(keys[3], isNot(keys[2]), reason: 'mismatch resets the key');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a double tap places only one request', (tester) async {
      when(
        () => orders.place(
          address: any(named: 'address'),
          paymentMethod: any(named: 'paymentMethod'),
          couponCode: any(named: 'couponCode'),
          shippingMethod: any(named: 'shippingMethod'),
          cartItemIds: any(named: 'cartItemIds'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        throw const AppException('Cannot reach the server.', code: 'NETWORK');
      });
      await pumpCheckout(tester);
      await fill(tester);
      await tester.scrollUntilVisible(
        find.text('Place order'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Place order'));
      await tester.tap(find.text('Place order'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(sentKeys(), hasLength(1));
    });
  });
}
