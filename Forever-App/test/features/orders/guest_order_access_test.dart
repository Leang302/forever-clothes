// The guest order access token (guestAccessToken) lives ONLY in memory for
// the current checkout: never persisted, never in a route, gone on restart
// or on login/logout. With it, the guest-orders endpoints are used.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/app/router/routes.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/orders/domain/entities/khqr_payment.dart';
import 'package:forever_app/features/orders/domain/entities/order.dart';
import 'package:forever_app/features/orders/domain/repositories/order_repository.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:forever_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOrders extends Mock implements OrderRepository {}

class _MockCart extends Mock implements CartRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _secret = 'guest-access-SECRET-123';

const _address = ShippingAddress(
  firstName: 'Real',
  lastName: 'Person',
  email: 'real@example.com',
  street: '1 Street',
  city: 'Phnom Penh',
  state: 'PP',
  zipcode: '12000',
  country: 'Cambodia',
  phone: '012345678',
);

final _order = Order(
  id: 42,
  status: OrderStatus.orderPlaced,
  paymentMethod: PaymentMethod.cod,
  paid: false,
  itemsAmount: 10,
  deliveryFee: 0,
  total: 10,
  address: _address,
  items: const [],
  createdAt: DateTime(2026),
  guest: true,
);

void main() {
  late _MockOrders orders;
  late _MockCart cart;

  setUpAll(() {
    registerFallbackValue(PaymentMethod.cod);
    registerFallbackValue(_address);
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    orders = _MockOrders();
    cart = _MockCart();
    when(() => cart.getCart()).thenAnswer((_) async => Cart.empty);
    when(
      () => orders.place(
        address: any(named: 'address'),
        paymentMethod: any(named: 'paymentMethod'),
        couponCode: any(named: 'couponCode'),
        shippingMethod: any(named: 'shippingMethod'),
        cartItemIds: any(named: 'cartItemIds'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => PlacedOrder(_order, guestAccessToken: _secret));
    when(
      () => orders.getGuestOrder(42, _secret),
    ).thenAnswer((_) async => _order);
  });

  ProviderContainer make({AppUser? user}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        orderRepositoryProvider.overrideWithValue(orders),
        cartRepositoryProvider.overrideWithValue(cart),
        currentUserProvider.overrideWithValue(user),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a guest order keeps its access token in memory only and reads the '
      'order through the guest endpoint', () async {
    final c = make();
    final placed = await c
        .read(ordersControllerProvider.notifier)
        .place(address: _address, paymentMethod: PaymentMethod.cod);
    expect(placed.id, 42);
    expect(c.read(guestOrderAccessProvider), {42: _secret});

    expect(await c.read(orderDetailProvider(42).future), _order);
    verify(() => orders.getGuestOrder(42, _secret)).called(1);
    verifyNever(() => orders.getById(any()));
    // Guests have no order history: the account list (403) is never asked.
    verifyNever(() => orders.list());

    // Not persisted anywhere.
    final keychain = await const FlutterSecureStorage().readAll();
    expect(keychain.values, isNot(contains(_secret)));
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      expect('${prefs.get(k)}', isNot(contains(_secret)));
    }
    // Never in a route, and never printed.
    expect(Routes.guestOrderPath(42), '/guest-order/42');
    expect(
      PlacedOrder(_order, guestAccessToken: _secret).toString(),
      isNot(contains(_secret)),
    );
  });

  test('after an app restart (new container) the token is gone', () async {
    final first = make();
    await first
        .read(ordersControllerProvider.notifier)
        .place(address: _address, paymentMethod: PaymentMethod.cod);
    expect(first.read(guestOrderAccessProvider), isNotEmpty);
    first.dispose();

    final restarted = make();
    expect(restarted.read(guestOrderAccessProvider), isEmpty);
  });

  test(
    'KHQR verify/cancel for a guest go through the guest endpoints',
    () async {
      when(
        () => orders.startKhqr(
          any(),
          couponCode: any(named: 'couponCode'),
          shippingMethod: any(named: 'shippingMethod'),
          cartItemIds: any(named: 'cartItemIds'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => KhqrPayment(
          orderId: 43,
          qrImage: 'data:image/png;base64,AA==',
          amount: 10,
          currency: 'USD',
          merchantName: 'Forever',
          expiresAt: DateTime(2030),
          guestAccessToken: _secret,
        ),
      );
      when(
        () => orders.verifyGuestKhqr(43, _secret),
      ).thenAnswer((_) async => true);
      when(
        () => orders.cancelGuestKhqr(43, _secret),
      ).thenAnswer((_) async => false);
      final c = make();
      final controller = c.read(ordersControllerProvider.notifier);
      await controller.startKhqr(_address);
      expect(await controller.verifyKhqr(43), isTrue);
      expect(await controller.cancelKhqr(43), isFalse);
      verify(() => orders.verifyGuestKhqr(43, _secret)).called(1);
      verify(() => orders.cancelGuestKhqr(43, _secret)).called(1);
      verifyNever(() => orders.verifyKhqr(any()));
      verifyNever(() => orders.cancelKhqr(any()));
      verifyNever(() => orders.list());
    },
  );

  test('a login forgets guest order access — even with the same e-mail '
      'nothing is attached to the account', () async {
    final auth = _MockAuth();
    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: 'pw',
      ),
    ).thenAnswer(
      (_) async => const AppUser(id: 7, name: 'X', email: 'real@example.com'),
    );
    when(() => orders.list()).thenAnswer((_) async => const []);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        orderRepositoryProvider.overrideWithValue(orders),
        cartRepositoryProvider.overrideWithValue(cart),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);
    c.listen(guestOrderAccessProvider, (_, _) {});
    await c
        .read(ordersControllerProvider.notifier)
        .place(address: _address, paymentMethod: PaymentMethod.cod);
    expect(c.read(guestOrderAccessProvider), {42: _secret});

    await c
        .read(authControllerProvider.notifier)
        .login('real@example.com', 'pw');
    expect(c.read(guestOrderAccessProvider), isEmpty);
    expect(await c.read(ordersControllerProvider.future), isEmpty);
  });

  testWidgets('the guest order screen without the in-memory token says '
      '"check your email" (e.g. after a restart)', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: OrderDetailScreen(orderId: 42, guest: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('guest-order-unavailable')), findsOneWidget);
    expect(find.text('Check your email'), findsOneWidget);
    verifyNever(() => orders.getById(any()));
    verifyNever(() => orders.getGuestOrder(any(), any()));
  });
}
