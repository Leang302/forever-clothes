import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/error/app_exception.dart';
import 'package:forever_app/core/storage/token_storage.dart';
import 'package:forever_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:forever_app/features/auth/data/models/user_dto.dart';
import 'package:forever_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late TokenStorage tokens;
  late AuthRepositoryImpl repo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    remote = _MockRemote();
    tokens = TokenStorage();
    await tokens.save(accessToken: 'a', refreshToken: 'r');
    repo = AuthRepositoryImpl(remote, tokens);
  });

  test('a stored session of a retired GUEST-role user is cleared: logged '
      'out', () async {
    when(() => remote.me()).thenAnswer(
      (_) async => const UserDto(
        id: 9,
        name: 'Guest',
        email: 'guest-9@guest.local',
        role: 'GUEST',
      ),
    );
    expect(await repo.restoreSession(), isNull);
    expect(tokens.hasSession, isFalse);
    final reloaded = TokenStorage();
    await reloaded.load();
    expect(reloaded.accessToken, isNull, reason: 'removed from the keychain');
  });

  test('an old GUEST JWT rejected with 403 is cleared too', () async {
    when(() => remote.me()).thenThrow(
      const AppException('Forbidden', code: 'FORBIDDEN', statusCode: 403),
    );
    expect(await repo.restoreSession(), isNull);
    expect(tokens.hasSession, isFalse);
  });

  test('a real customer session is restored', () async {
    when(() => remote.me()).thenAnswer(
      (_) async =>
          const UserDto(id: 1, name: 'Tola', email: 't@x.com', role: 'USER'),
    );
    expect((await repo.restoreSession())?.id, 1);
    expect(tokens.hasSession, isTrue);
  });

  test('offline keeps the tokens for the next start', () async {
    when(
      () => remote.me(),
    ).thenThrow(const AppException('offline', code: 'NETWORK'));
    await expectLater(repo.restoreSession(), throwsA(isA<AppException>()));
    expect(tokens.hasSession, isTrue);
  });
}
