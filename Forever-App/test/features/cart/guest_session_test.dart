// Guest cart sessions: lazily created, persisted under their own key,
// separate from (and never merged into) an account's cart, revoked on login.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/error/app_exception.dart';
import 'package:forever_app/core/network/network_providers.dart';
import 'package:forever_app/core/storage/guest_session_storage.dart';
import 'package:forever_app/core/storage/storage_providers.dart';
import 'package:forever_app/core/storage/token_storage.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/data/datasources/guest_session_remote_data_source.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/guest_session_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockCart extends Mock implements CartRepository {}

class _MockGuestRemote extends Mock implements GuestSessionRemoteDataSource {}

const _user = AppUser(id: 1, name: 'Tola', email: 'x@example.com');

Cart _cartOf(int productId) => Cart(
  items: [
    CartLine(
      id: productId,
      productId: productId,
      name: 'P$productId',
      price: 10,
      size: 'M',
      quantity: 1,
    ),
  ],
  itemCount: 1,
  subtotal: 10,
  deliveryFee: 0,
  total: 10,
);

final _guestCart = _cartOf(100); // item A
final _accountCart = _cartOf(200);

void main() {
  late _MockAuth auth;
  late _MockCart cart;
  late _MockGuestRemote remote;
  late GuestSessionStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _MockAuth();
    cart = _MockCart();
    remote = _MockGuestRemote();
    storage = GuestSessionStorage();
    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => remote.end(any())).thenAnswer((_) async {});
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        cartRepositoryProvider.overrideWithValue(cart),
        guestSessionRemoteDataSourceProvider.overrideWithValue(remote),
        guestSessionStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> keychainGuestToken() =>
      const FlutterSecureStorage().read(key: GuestSessionStorage.key);

  group('ensureGuestSession', () {
    test('concurrent add-to-cart callers share ONE new session, persisted '
        'under its own key (not the login keys)', () async {
      when(() => remote.start()).thenAnswer(
        (_) => Future.delayed(const Duration(milliseconds: 20), () => 'g1'),
      );
      final c = make();
      final session = c.read(guestSessionProvider.notifier);
      final tokens = await Future.wait([
        session.ensureGuestSession(),
        session.ensureGuestSession(),
        session.ensureGuestSession(),
      ]);
      expect(tokens, everyElement('g1'));
      verify(() => remote.start()).called(1);
      expect(c.read(guestSessionProvider), 'g1');
      expect(await keychainGuestToken(), 'g1');
      final all = await const FlutterSecureStorage().readAll();
      expect(all.keys, [GuestSessionStorage.key]);
      // Already have one: no further sessions.
      expect(await session.ensureGuestSession(), 'g1');
      verifyNever(() => remote.start());
    });

    test('surfaces the 429 rate-limit error and stores nothing', () async {
      when(() => remote.start()).thenThrow(
        const AppException(
          'Too many guest sessions',
          code: 'TOO_MANY_GUEST_SESSIONS',
          statusCode: 429,
        ),
      );
      final c = make();
      await expectLater(
        c.read(guestSessionProvider.notifier).ensureGuestSession(),
        throwsA(isA<AppException>()),
      );
      expect(c.read(guestSessionProvider), isNull);
      expect(await keychainGuestToken(), isNull);
    });
  });

  group('cart provider', () {
    test('anonymous without a session: empty, no API call, no session '
        'created', () async {
      final c = make();
      expect(await c.read(cartControllerProvider.future), Cart.empty);
      verifyNever(() => cart.getCart());
      verifyNever(() => remote.start());
      expect(c.read(currentUserProvider), isNull);
    });

    test('anonymous with a stored session: loads the guest cart and stays '
        'logged out — also after an app restart (fresh container, same '
        'secure storage)', () async {
      await storage.save('g1');
      when(() => cart.getCart()).thenAnswer((_) async => _guestCart);
      final c = make();
      await c.read(authControllerProvider.future);
      expect(await c.read(cartControllerProvider.future), _guestCart);
      expect(c.read(currentUserProvider), isNull);
      c.dispose();

      // "Restart": a new storage instance loading from the same keychain.
      storage = GuestSessionStorage();
      await storage.load();
      expect(storage.token, 'g1');
      final restarted = make();
      await restarted.read(authControllerProvider.future);
      expect(await restarted.read(cartControllerProvider.future), _guestCart);
      expect(restarted.read(currentUserProvider), isNull);
    });

    test('GUEST_SESSION_EXPIRED resets the guest cart to empty', () async {
      await storage.save('g1');
      when(() => cart.getCart()).thenAnswer((_) async => _guestCart);
      final c = make();
      await c.read(authControllerProvider.future);
      await c.read(cartControllerProvider.future);
      // What the interceptor does on the 401:
      await storage.clear();
      c.read(guestSessionExpiredProvider.notifier).trigger();
      expect(c.read(cartControllerProvider).value, Cart.empty);
      expect(c.read(guestSessionProvider), isNull);
    });
  });

  group('login / registration transition', () {
    test('login revokes + deletes the guest session and shows ONLY the '
        "account's cart (no merge)", () async {
      await storage.save('guest-A');
      var loggedIn = false;
      when(
        () => cart.getCart(),
      ).thenAnswer((_) async => loggedIn ? _accountCart : _guestCart);
      when(
        () => auth.login(
          email: any(named: 'email'),
          password: 'pw',
        ),
      ).thenAnswer((_) async {
        loggedIn = true;
        return _user;
      });
      final c = make();
      await c.read(authControllerProvider.future);
      expect(await c.read(cartControllerProvider.future), _guestCart);

      await c.read(authControllerProvider.notifier).login(_user.email, 'pw');

      verify(() => remote.end('guest-A')).called(1);
      expect(storage.token, isNull);
      expect(await keychainGuestToken(), isNull);
      expect(c.read(guestSessionProvider), isNull);
      expect(c.read(currentUserProvider), _user);
      expect(await c.read(cartControllerProvider.future), _accountCart);
      // Nothing from the guest cart was copied into the account.
      verifyNever(
        () => cart.add(
          productId: any(named: 'productId'),
          size: any(named: 'size'),
          quantity: any(named: 'quantity'),
        ),
      );
      verifyNever(
        () => cart.setQuantity(
          productId: any(named: 'productId'),
          size: any(named: 'size'),
          quantity: any(named: 'quantity'),
        ),
      );
    });

    test(
      'a failing revoke still deletes the guest token and logs in',
      () async {
        await storage.save('guest-A');
        when(() => remote.end(any())).thenThrow(const AppException('offline'));
        when(
          () => auth.login(
            email: any(named: 'email'),
            password: 'pw',
          ),
        ).thenAnswer((_) async => _user);
        when(() => cart.getCart()).thenAnswer((_) async => _accountCart);
        final c = make();
        await c.read(authControllerProvider.future);
        await c.read(authControllerProvider.notifier).login(_user.email, 'pw');
        expect(storage.token, isNull);
        expect(c.read(currentUserProvider), _user);
      },
    );

    test(
      'email verification (registration) also drops the guest session',
      () async {
        await storage.save('guest-A');
        when(
          () => auth.verifyEmail(
            email: any(named: 'email'),
            otp: '123456',
          ),
        ).thenAnswer((_) async => _user);
        when(() => cart.getCart()).thenAnswer((_) async => _accountCart);
        final c = make();
        await c.read(authControllerProvider.future);
        await c
            .read(authControllerProvider.notifier)
            .verifyEmail(_user.email, '123456');
        verify(() => remote.end('guest-A')).called(1);
        expect(storage.token, isNull);
      },
    );

    test('a failed login keeps the guest cart session', () async {
      await storage.save('guest-A');
      when(
        () => auth.login(
          email: any(named: 'email'),
          password: 'bad',
        ),
      ).thenThrow(const AppException('Invalid email or password'));
      final c = make();
      await c.read(authControllerProvider.future);
      await expectLater(
        c.read(authControllerProvider.notifier).login(_user.email, 'bad'),
        throwsA(isA<AppException>()),
      );
      expect(storage.token, 'guest-A');
      verifyNever(() => remote.end(any()));
    });

    test(
      'logout leaves a fresh anonymous visitor with an empty cart',
      () async {
        when(() => auth.restoreSession()).thenAnswer((_) async => _user);
        when(() => cart.getCart()).thenAnswer((_) async => _accountCart);
        final c = make();
        await c.read(authControllerProvider.future);
        expect(await c.read(cartControllerProvider.future), _accountCart);

        await c.read(authControllerProvider.notifier).logout();
        expect(c.read(currentUserProvider), isNull);
        expect(await c.read(cartControllerProvider.future), Cart.empty);
        expect(storage.token, isNull);
        verifyNever(() => remote.start());
      },
    );

    test('a restored login drops a leftover guest session', () async {
      await storage.save('stale');
      when(() => auth.restoreSession()).thenAnswer((_) async => _user);
      final c = make();
      await c.read(authControllerProvider.future);
      verify(() => remote.end('stale')).called(1);
      expect(storage.token, isNull);
    });
  });

  test('TokenStorage and GuestSessionStorage use separate keys', () async {
    final tokens = TokenStorage();
    await tokens.save(accessToken: 'a', refreshToken: 'r');
    await storage.save('g');
    await tokens.clear(); // logging out does not touch the guest key ...
    expect(await keychainGuestToken(), 'g');
    await storage.clear(); // ... and dropping the guest key keeps a login
    await tokens.save(accessToken: 'a', refreshToken: 'r');
    await storage.save('g');
    await storage.clear();
    final again = TokenStorage();
    await again.load();
    expect(again.accessToken, 'a');
  });
}
