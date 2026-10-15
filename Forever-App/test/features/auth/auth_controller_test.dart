import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/error/app_exception.dart';
import 'package:forever_app/core/network/network_providers.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AppUser(id: 1, name: 'Tola', email: 'tola@example.com');

ProviderContainer _container(MockAuthRepository repo) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockAuthRepository repo;

  setUp(() => repo = MockAuthRepository());

  test('restores a saved session on start', () async {
    when(() => repo.restoreSession()).thenAnswer((_) async => _user);
    final container = _container(repo);

    expect(await container.read(authControllerProvider.future), _user);
    expect(container.read(currentUserProvider), _user);
  });

  test('starts logged out when the server is unreachable', () async {
    when(
      () => repo.restoreSession(),
    ).thenThrow(const AppException('offline', code: 'NETWORK'));
    final container = _container(repo);

    expect(await container.read(authControllerProvider.future), isNull);
  });

  test(
    'login stores the user; a failed login leaves the session untouched',
    () async {
      when(() => repo.restoreSession()).thenAnswer((_) async => null);
      final container = _container(repo);
      await container.read(authControllerProvider.future);

      when(
        () => repo.login(email: 'bad@example.com', password: 'x'),
      ).thenThrow(const AppException('Invalid email or password'));
      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login('bad@example.com', 'x'),
        throwsA(isA<AppException>()),
      );
      expect(container.read(currentUserProvider), isNull);

      when(
        () => repo.login(email: 'tola@example.com', password: 'pw'),
      ).thenAnswer((_) async => _user);
      await container
          .read(authControllerProvider.notifier)
          .login('tola@example.com', 'pw');
      expect(container.read(currentUserProvider), _user);
    },
  );

  test('logout clears the user', () async {
    when(() => repo.restoreSession()).thenAnswer((_) async => _user);
    when(() => repo.logout()).thenAnswer((_) async {});
    final container = _container(repo);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(currentUserProvider), isNull);
    verify(() => repo.logout()).called(1);
  });

  test('an expired refresh token drops the session', () async {
    when(() => repo.restoreSession()).thenAnswer((_) async => _user);
    final container = _container(repo);
    await container.read(authControllerProvider.future);

    container.read(sessionExpiredProvider.notifier).trigger();
    expect(container.read(currentUserProvider), isNull);
  });
}
