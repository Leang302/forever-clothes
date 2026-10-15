import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/app/router/app_router.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/catalog/domain/entities/catalog_filters.dart';
import 'package:forever_app/features/catalog/domain/entities/paged_result.dart';
import 'package:forever_app/features/catalog/domain/entities/product_query.dart';
import 'package:forever_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:forever_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:forever_app/features/orders/domain/repositories/order_repository.dart';
import 'package:forever_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCartRepository extends Mock implements CartRepository {}

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

const _user = AppUser(id: 1, name: 'Tola', email: 'tola@example.com');

void main() {
  late MockAuthRepository auth;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    auth = MockAuthRepository();
    final cart = MockCartRepository();
    final catalog = MockCatalogRepository();
    final orders = MockOrderRepository();

    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    when(() => cart.getCart()).thenAnswer((_) async => Cart.empty);
    when(() => orders.list()).thenAnswer((_) async => []);
    when(
      () => catalog.latest(limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);
    when(
      () => catalog.bestsellers(limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);
    when(() => catalog.filters()).thenAnswer(
      (_) async => const CatalogFilters(categories: [], subCategories: []),
    );
    when(() => catalog.search(any(), page: any(named: 'page'))).thenAnswer(
      (_) async =>
          const PagedResult(items: [], page: 0, isLast: true, total: 0),
    );

    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        cartRepositoryProvider.overrideWithValue(cart),
        catalogRepositoryProvider.overrideWithValue(catalog),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a protected route sends a logged-out user to login with a redirect back',
    (tester) async {
      await pumpApp(tester);
      final router = container.read(appRouterProvider);

      router.go('/orders');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/login');
      expect(router.state.uri.queryParameters['redirect'], '/orders');
    },
  );

  testWidgets(
    'entering the OTP signs in and leaves the pushed verify-email screen',
    (tester) async {
      when(
        () => auth.verifyEmail(email: 'a@b.c', otp: '123456'),
      ).thenAnswer((_) async => _user);
      await pumpApp(tester);
      final router = container.read(appRouterProvider);

      unawaited(router.push('/verify-email?email=a%40b.c'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/verify-email');

      await tester.enterText(
        find.byType(EditableText),
        '123456',
      ); // completes the code -> auto submit
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(container.read(currentUserProvider), _user);
    },
  );

  testWidgets('logging in goes back to where the user came from', (
    tester,
  ) async {
    when(
      () => auth.login(email: 'tola@example.com', password: 'secret'),
    ).thenAnswer((_) async => _user);
    await pumpApp(tester);
    final router = container.read(appRouterProvider);

    router.go('/orders'); // protected: redirected to /login?redirect=/orders
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/login');

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tola@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Log in').last);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/orders');
  });

  testWidgets('a logged-in user is bounced away from the login screen', (
    tester,
  ) async {
    when(() => auth.restoreSession()).thenAnswer((_) async => _user);
    await pumpApp(tester);
    final router = container.read(appRouterProvider);

    router.go('/login');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });
}

void unawaited(Future<void> future) {}
