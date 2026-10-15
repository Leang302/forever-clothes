import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
  AuthRemoteDataSource(ref.watch(dioProvider)),
  ref.watch(tokenStorageProvider),
);

/// Session state: `AsyncData(user)` when logged in, `AsyncData(null)` when logged out.
///
/// Action methods throw [AppException]; screens catch it and show the message, so a failed login
/// never disturbs the current session state.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AppUser?> build() async {
    // The refresh token was rejected somewhere in the app: drop to logged-out.
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));
    final repository = ref.watch(authRepositoryProvider);
    try {
      return await repository.restoreSession().timeout(
        const Duration(seconds: 6),
      );
    } on Exception {
      return null; // offline at launch: show the logged-out UI, tokens are kept for the next start
    }
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> login(String email, String password) async {
    state = AsyncData(await _repo.login(email: email, password: password));
  }

  Future<void> register(String name, String email, String password) =>
      _repo.register(name: name, email: email, password: password);

  Future<void> verifyEmail(String email, String otp) async {
    state = AsyncData(await _repo.verifyEmail(email: email, otp: otp));
  }

  Future<void> resendOtp(String email, OtpPurpose purpose) =>
      _repo.resendOtp(email: email, purpose: purpose);

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email);

  Future<void> resetPassword(String email, String otp, String newPassword) =>
      _repo.resetPassword(email: email, otp: otp, newPassword: newPassword);

  Future<void> updateProfile(String name, String? phone) async {
    state = AsyncData(await _repo.updateProfile(name: name, phone: phone));
  }

  Future<void> changePassword(String current, String next) =>
      _repo.changePassword(currentPassword: current, newPassword: next);

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

/// The logged-in user, or null (also while the session is still being restored).
@Riverpod(keepAlive: true)
AppUser? currentUser(Ref ref) => ref.watch(authControllerProvider).value;
