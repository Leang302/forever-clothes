import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/guest_session_storage.dart';
import '../storage/token_storage.dart';

/// Attaches the caller's identity to API requests — a login OR an anonymous
/// guest cart session, never both (the API answers 400 AMBIGUOUS_IDENTITY):
///
/// * logged in (an access token exists): `Authorization: Bearer …` only. On a
///   401 the token pair is refreshed once (single-flight) and the request
///   retried.
/// * anonymous with a guest token: `X-Guest-Session: …`, and only on the
///   guest-shopping endpoints ([isGuestSessionRequest]). A 401
///   `GUEST_SESSION_EXPIRED` deletes the stored guest token (see
///   [onGuestSessionExpired]) and never triggers the login refresh/logout.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.client,
    required this.refreshClient,
    required this.tokens,
    required this.guestSession,
    required this.onSessionExpired,
    required this.onGuestSessionExpired,
  });

  /// Opt-out flag for public endpoints and for calls that set their own
  /// identity header (`Options(extra: {AuthInterceptor.skipAuth: true})`):
  /// nothing is attached and nothing is refreshed.
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';

  static const guestSessionHeader = 'X-Guest-Session';
  static const authorizationHeader = 'Authorization';
  static const guestSessionExpiredCode = 'GUEST_SESSION_EXPIRED';

  final Dio client;
  final Dio refreshClient; // no interceptors: a failing refresh cannot loop
  final TokenStorage tokens;
  final GuestSessionStorage guestSession;

  /// The login refresh token was rejected: the user is logged out.
  final void Function() onSessionExpired;

  /// The guest token was unknown/expired; it has already been deleted.
  final void Function() onGuestSessionExpired;

  Future<bool>? _refreshing;

  /// The only endpoints a guest cart session may be sent to:
  /// `/api/cart/**`, `/api/checkout/**`, `POST /api/orders` and
  /// `POST /api/khqr/checkout`.
  static bool isGuestSessionRequest(String method, String path) {
    final p = Uri.parse(path).path;
    bool under(String root) => p == root || p.startsWith('$root/');
    final post = method.toUpperCase() == 'POST';
    return under('/api/cart') ||
        under('/api/checkout') ||
        (post && p == '/api/orders') ||
        (post && p == '/api/khqr/checkout');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipAuth] == true) return handler.next(options);
    // Whatever the caller passed, the interceptor decides the identity.
    options.headers.remove(authorizationHeader);
    options.headers.remove(guestSessionHeader);
    final access = tokens.accessToken;
    final guest = guestSession.token;
    if (access != null) {
      options.headers[authorizationHeader] = 'Bearer $access';
    } else if (guest != null &&
        isGuestSessionRequest(options.method, options.path)) {
      options.headers[guestSessionHeader] = guest;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final sentGuest = req.headers[guestSessionHeader] as String?;

    if (sentGuest != null) {
      // Guest calls never touch the login refresh/logout logic.
      if (status == 401 && _code(err) == guestSessionExpiredCode) {
        // Only drop the token we actually sent (a newer one may exist by now).
        if (guestSession.token == sentGuest) {
          await guestSession.clear();
          onGuestSessionExpired();
        }
      }
      return handler.next(err);
    }

    final canRefresh =
        status == 401 &&
        req.extra[skipAuth] != true &&
        req.extra[_retried] != true &&
        req.headers.containsKey(authorizationHeader) &&
        tokens.refreshToken != null;
    if (!canRefresh) return handler.next(err);

    final refreshed = await (_refreshing ??= _refresh().whenComplete(
      () => _refreshing = null,
    ));
    if (!refreshed) return handler.next(err);

    req.extra[_retried] = true;
    req.headers[authorizationHeader] = 'Bearer ${tokens.accessToken}';
    try {
      handler.resolve(await client.fetch<dynamic>(req));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static String? _code(DioException e) {
    final body = e.response?.data;
    return body is Map ? body['code'] as String? : null;
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
