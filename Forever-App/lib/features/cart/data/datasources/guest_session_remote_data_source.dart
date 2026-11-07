import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/network/auth_interceptor.dart';

/// Anonymous cart sessions (`/api/guest-sessions`). Neither call carries a
/// login token: [start] is public and [end] identifies the session only by
/// its own `X-Guest-Session` header.
class GuestSessionRemoteDataSource {
  GuestSessionRemoteDataSource(this._dio);

  final Dio _dio;

  /// Returns the new opaque session token. 429 TOO_MANY_GUEST_SESSIONS when
  /// this network started too many sessions recently.
  Future<String> start() => guardApi(() async {
    final res = await _dio.post<Json>(
      '/api/guest-sessions',
      options: Options(extra: {AuthInterceptor.skipAuth: true}),
    );
    return res.data!['token'] as String;
  });

  /// Ends the session server-side and discards its cart (orders are kept).
  Future<void> end(String token) => guardApi(
    () => _dio.delete<void>(
      '/api/guest-sessions/current',
      options: Options(
        extra: {AuthInterceptor.skipAuth: true},
        headers: {AuthInterceptor.guestSessionHeader: token},
      ),
    ),
  );
}
