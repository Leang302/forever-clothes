import '../entities/app_user.dart';

enum OtpPurpose {
  verifyEmail('VERIFY_EMAIL'),
  resetPassword('RESET_PASSWORD');

  const OtpPurpose(this.apiValue);
  final String apiValue;
}

abstract interface class AuthRepository {
  /// The saved session's user, or null when logged out. Throws on network failure.
  Future<AppUser?> restoreSession();

  Future<AppUser> login({required String email, required String password});

  /// Creates the account and e-mails a verification OTP.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> verifyEmail({required String email, required String otp});

  Future<void> resendOtp({required String email, required OtpPurpose purpose});

  Future<void> forgotPassword(String email);

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<void> logout();

  Future<AppUser> updateProfile({required String name, String? phone});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
