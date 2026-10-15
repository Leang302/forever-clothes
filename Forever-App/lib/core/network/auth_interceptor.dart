import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Adds the bearer token and, on a 401, refreshes the pair once (single-flight) and retries the request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.client,
    required this.refreshClient,
    required this.tokens,
    required this.onSessionExpired,
  });

  /// Opt-out flag for public endpoints (`Options(extra: {AuthInterceptor.skipAuth: true})`).
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';

  final Dio client;
  final Dio refreshClient; // no interceptors: a failing refresh cannot loop
  final TokenStorage tokens;
  final void Function() onSessionExpired;

  Future<bool>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokens.accessToken;
    if (options.extra[skipAuth] != true && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final canRefresh =
        err.response?.statusCode == 401 &&
        req.extra[skipAuth] != true &&
        req.extra[_retried] != true &&
        tokens.refreshToken != null;
    if (!canRefresh) return handler.next(err);

    final refreshed = await (_refreshing ??= _refresh().whenComplete(
      () => _refreshing = null,
    ));
    if (!refreshed) return handler.next(err);

    req.extra[_retried] = true;
    req.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    try {
      handler.resolve(await client.fetch<dynamic>(req));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refresh() async {
    try {
      final res = await refreshClient.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );
      await tokens.save(
        accessToken: res.data!['accessToken'] as String,
        refreshToken: res.data!['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        await tokens.clear();
        onSessionExpired();
      }
      return false;
    }
  }
}
