// Real network test against the live backend (Forever-API on
// http://localhost:8989 — must be running, same as the simulator uses).
// Verifies, at the provider/repository/network layer (the UI flow is
// covered by guest_checkout_test.dart):
//
//  1. ensureGuestSession() starts ONE anonymous guest cart session
//     (POST /api/guest-sessions), stored under its own key — NOT a login:
//     currentUserProvider stays null, no login tokens are stored.
//  2. A guest can add a real item to their real server-side cart
//     (X-Guest-Session attached by the interceptor).
//  3. Placing an order with an idempotencyKey creates a guest order and
//     returns a guestAccessToken (kept in memory only).
//  4. Resubmitting the SAME key returns the SAME order and the SAME access
//     token instead of a duplicate.
//  5. Reusing that key with DIFFERENT details -> 409 IDEMPOTENCY_KEY_MISMATCH.
//  6. The access token opens the order on /api/guest-orders/{id}; a wrong
//     token -> 404; the guest session cannot read account endpoints (403).
//
// Run on a real device/simulator with:
//   flutter test integration_test/guest_checkout_idempotency_test.dart -d <device>
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/error/app_exception.dart';
import 'package:forever_app/core/storage/guest_session_storage.dart';
import 'package:forever_app/core/storage/storage_providers.dart';
import 'package:forever_app/core/storage/token_storage.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/guest_session_providers.dart';
import 'package:forever_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:forever_app/features/orders/domain/entities/order.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late TokenStorage tokens;

  setUp(() async {
    tokens = TokenStorage();
    await tokens.load();
    await tokens.clear();
    final guest = GuestSessionStorage();
    await guest.load();
    await guest.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        guestSessionStorageProvider.overrideWithValue(guest),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    // End the session (discards its cart; the orders stay).
    await container.read(guestSessionProvider.notifier).end();
    container.dispose();
  });

  testWidgets('guest session + add to cart + idempotent order placement', (
    tester,
  ) async {
    // 1. Anonymous guest cart session (what add-to-cart does lazily).
    await container.read(authControllerProvider.future);
    expect(container.read(currentUserProvider), isNull);
    final session = container.read(guestSessionProvider.notifier);
    final both = await Future.wait([
      session.ensureGuestSession(),
      session.ensureGuestSession(),
    ]);
    expect(both[0], both[1], reason: 'concurrent callers share one session');
    final guestToken = both[0];
    expect(await storedGuestToken(), guestToken);
    expect(container.read(currentUserProvider), isNull, reason: 'not a login');
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);

    // 2. Real add-to-cart against the real backend.
    final products = await container.read(latestProductsProvider.future);
    final product = products.firstWhere((p) => p.sizes.isNotEmpty && p.canBuy);
    final size = product.sizes.firstWhere((s) => product.stockOf(s) > 2);
    await container
        .read(cartControllerProvider.notifier)
        .add(product.id, size, quantity: 1);
    expect(container.read(cartControllerProvider).value!.isEmpty, isFalse);

    // 3 & 4. Place with a key, then resend the exact same key.
    final email =
        'it.idem.${DateTime.now().millisecondsSinceEpoch}@example.com';
    final address = ShippingAddress(
      firstName: 'Idem',
      lastName: 'Potent',
      email: email,
      street: '123 Real St',
      city: 'Phnom Penh',
      state: 'Phnom Penh',
      zipcode: '12000',
      country: 'Cambodia',
      phone: '012 345 678',
    );
    final rand = Random.secure();
    final key = List.generate(
      32,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();
    final repo = container.read(orderRepositoryProvider);

    final first = await repo.place(
      address: address,
      paymentMethod: PaymentMethod.cod,
      idempotencyKey: key,
    );
    debugPrint('IT_GUEST_ORDER idem=${first.order.id}');
    expect(first.order.id, isPositive);
    expect(first.order.guest, isTrue);
    expect(first.guestAccessToken, isNotNull);

    // Same item back in the cart so a duplicate WOULD be possible.
    await container
        .read(cartControllerProvider.notifier)
        .add(product.id, size, quantity: 1);
    final retry = await repo.place(
      address: address,
      paymentMethod: PaymentMethod.cod,
      idempotencyKey: key,
    );
    expect(retry.order.id, first.order.id, reason: 'no duplicate order');
    expect(retry.guestAccessToken, first.guestAccessToken);

    // 5. Same key, different details -> 409.
    await expectLater(
      repo.place(
        address: address.copyWith(street: '999 Different Rd'),
        paymentMethod: PaymentMethod.cod,
        idempotencyKey: key,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'IDEMPOTENCY_KEY_MISMATCH',
        ),
      ),
    );

    // 6. Guest order access rules.
    final viaToken = await repo.getGuestOrder(
      first.order.id,
      first.guestAccessToken!,
    );
    expect(viaToken.id, first.order.id);
    await expectLater(
      repo.getGuestOrder(first.order.id, 'wrong-token'),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 404)),
    );
    final probe = plainDio();
    final me = await probe.get<Object?>(
      '/api/users/me',
      options: Options(headers: {'X-Guest-Session': guestToken}),
    );
    expect(me.statusCode, 403, reason: 'guest session is not an account');
    final both401 = await probe.get<Object?>(
      '/api/cart',
      options: Options(
        headers: {'X-Guest-Session': guestToken, 'Authorization': 'Bearer x'},
      ),
    );
    expect(both401.statusCode, 400, reason: 'AMBIGUOUS_IDENTITY');
    expect((both401.data! as Map)['code'], 'AMBIGUOUS_IDENTITY');

    // Clean up the extra cart line from step 4.
    final leftover = container.read(cartControllerProvider).value!.items;
    for (final l in leftover) {
      await container.read(cartControllerProvider.notifier).remove(l);
    }
  });
}
