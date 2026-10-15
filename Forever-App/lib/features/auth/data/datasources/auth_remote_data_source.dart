import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../models/auth_response_dto.dart';
import '../models/user_dto.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// Public endpoints must not carry (or trigger a refresh of) the bearer token.
  static final _public = Options(extra: {AuthInterceptor.skipAuth: true});

  Future<void> register(String name, String email, String password) => guardApi(
    () => _dio.post<void>(
      '/api/auth/register',
      data: {'name': name, 'email': email, 'password': password},
      options: _public,
    ),
  );

  Future<AuthResponseDto> verifyEmail(String email, String otp) =>
      guardApi(() async {
        final res = await _dio.post<Json>(
          '/api/auth/verify-email',
          data: {'email': email, 'otp': otp},
          options: _public,
        );
        return AuthResponseDto.fromJson(res.data!);
      });

  Future<void> resendOtp(String email, String purpose) => guardApi(
    () => _dio.post<void>(
      '/api/auth/resend-otp',
      data: {'email': email, 'purpose': purpose},
      options: _public,
    ),
  );

  Future<AuthResponseDto> login(String email, String password) =>
      guardApi(() async {
        final res = await _dio.post<Json>(
          '/api/auth/login',
          data: {'email': email, 'password': password},
          options: _public,
        );
        return AuthResponseDto.fromJson(res.data!);
      });

  Future<void> logout(String refreshToken) => guardApi(
    () => _dio.post<void>(
      '/api/auth/logout',
      data: {'refreshToken': refreshToken},
      options: _public,
    ),
  );

  Future<void> forgotPassword(String email) => guardApi(
    () => _dio.post<void>(
      '/api/auth/forgot-password',
      data: {'email': email},
      options: _public,
    ),
  );

  Future<void> resetPassword(String email, String otp, String newPassword) =>
      guardApi(
        () => _dio.post<void>(
          '/api/auth/reset-password',
          data: {'email': email, 'otp': otp, 'newPassword': newPassword},
          options: _public,
        ),
      );

  Future<UserDto> me() => guardApi(
    () async => UserDto.fromJson((await _dio.get<Json>('/api/users/me')).data!),
  );

  Future<UserDto> updateProfile(String name, String? phone) => guardApi(
    () async => UserDto.fromJson(
      (await _dio.put<Json>(
        '/api/users/me',
        data: {'name': name, 'phone': phone},
      )).data!,
    ),
  );

  Future<void> changePassword(String current, String next) => guardApi(
    () => _dio.post<void>(
      '/api/users/me/change-password',
      data: {'currentPassword': current, 'newPassword': next},
    ),
  );
}
