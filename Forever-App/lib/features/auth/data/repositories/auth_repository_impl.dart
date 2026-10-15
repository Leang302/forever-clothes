import '../../../../core/error/app_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_response_dto.dart';
import '../models/user_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<AppUser?> restoreSession() async {
    if (!_tokens.hasSession) return null;
    try {
      return (await _remote.me()).toEntity();
    } on AppException catch (e) {
      if (e.isUnauthorized || e.statusCode == 403) {
        await _tokens.clear();
        return null;
      }
      rethrow; // offline: keep the tokens, let the caller decide
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async => _startSession(await _remote.login(email.trim(), password));

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => _remote.register(name.trim(), email.trim(), password);

  @override
  Future<AppUser> verifyEmail({
    required String email,
    required String otp,
  }) async =>
      _startSession(await _remote.verifyEmail(email.trim(), otp.trim()));

  @override
  Future<void> resendOtp({
    required String email,
    required OtpPurpose purpose,
  }) => _remote.resendOtp(email.trim(), purpose.apiValue);

  @override
  Future<void> forgotPassword(String email) =>
      _remote.forgotPassword(email.trim());

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) => _remote.resetPassword(email.trim(), otp.trim(), newPassword);

  @override
  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _remote.logout(refresh);
      } on AppException {
        // The token is dropped locally either way.
      }
    }
    await _tokens.clear();
  }

  @override
  Future<AppUser> updateProfile({required String name, String? phone}) async =>
      (await _remote.updateProfile(
        name.trim(),
        (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      )).toEntity();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _remote.changePassword(currentPassword, newPassword);

  Future<AppUser> _startSession(AuthResponseDto res) async {
    await _tokens.save(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
    return res.user.toEntity();
  }
}
