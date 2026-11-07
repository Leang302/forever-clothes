import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/network/auth_interceptor.dart';
import 'package:forever_app/core/storage/guest_session_storage.dart';
import 'package:forever_app/core/storage/token_storage.dart';

/// Records every request that reaches the wire and answers with [respond].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _guestToken = 'guest-token-abc';

void main() {
  late TokenStorage tokens;
  late GuestSessionStorage guest;
  late _Adapter api;
  late _Adapter refreshApi;
  late Dio dio;
  late int sessionExpired;
  late int guestExpired;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokens = TokenStorage();
    guest = GuestSessionStorage();
    sessionExpired = 0;
    guestExpired = 0;
    api = _Adapter((_) => _json(200, {'ok': true}));
    refreshApi = _Adapter(
      (_) => _json(200, {'accessToken': 'new-access', 'refreshToken': 'new-r'}),
    );
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://api'))
      ..httpClientAdapter = refreshApi;
    dio = Dio(BaseOptions(baseUrl: 'http://api'))..httpClientAdapter = api;
    dio.interceptors.add(
      AuthInterceptor(
        client: dio,
        refreshClient: refreshClient,
        tokens: tokens,
        guestSession: guest,
        onSessionExpired: () => sessionExpired++,
        onGuestSessionExpired: () => guestExpired++,
      ),
    );
  });

  Map<String, dynamic> sentHeaders() => api.requests.last.headers;

  group('which endpoints may carry X-Guest-Session', () {
    for (final (method, path) in [
      ('GET', '/api/cart'),
      ('POST', '/api/cart/items'),
      ('PUT', '/api/cart/items'),
      ('DELETE', '/api/cart/items/3'),
      ('GET', '/api/checkout/options'),
      ('POST', '/api/checkout/coupon'),
      ('POST', '/api/orders'),
      ('POST', '/api/khqr/checkout'),
    ]) {
      test('$method $path: yes', () {
        expect(AuthInterceptor.isGuestSessionRequest(method, path), isTrue);
      });
    }
    for (final (method, path) in [
      ('GET', '/api/orders'), // account order history
      ('GET', '/api/orders/5'),
      ('POST', '/api/orders/5/cancel'),
      ('POST', '/api/khqr/5/verify'),
      ('GET', '/api/users/me'),
      ('GET', '/api/wishlist'),
      ('GET', '/api/addresses'),
      ('GET', '/api/products'),
      ('GET', '/api/cartography'), // prefix lookalike
      ('GET', '/api/guest-orders/5'),
    ]) {
      test('$method $path: no', () {
        expect(AuthInterceptor.isGuestSessionRequest(method, path), isFalse);
      });
    }
  });

  test('anonymous with a guest token: X-Guest-Session on cart, no '
      'Authorization', () async {
    await guest.save(_guestToken);
    await dio.get<void>('/api/cart');
    expect(sentHeaders()['X-Guest-Session'], _guestToken);
    expect(sentHeaders().containsKey('Authorization'), isFalse);

    await dio.post<void>('/api/orders', data: {});
    expect(sentHeaders()['X-Guest-Session'], _guestToken);
  });

  test('anonymous with a guest token: nothing on account/public '
      'endpoints', () async {
    await guest.save(_guestToken);
    for (final path in ['/api/orders', '/api/users/me', '/api/products']) {
      await dio.get<void>(path);
      expect(
        sentHeaders().containsKey('X-Guest-Session'),
        isFalse,
        reason: path,
      );
      expect(sentHeaders().containsKey('Authorization'), isFalse, reason: path);
    }
  });

  test('NEVER both headers: a login wins even if a guest token is stored, '
      'and caller-supplied identity headers are replaced', () async {
    await guest.save(_guestToken);
    await tokens.save(accessToken: 'acc', refreshToken: 'ref');
    for (final path in ['/api/cart', '/api/checkout/options', '/api/orders']) {
      await dio.get<void>(
        path,
        options: Options(
          headers: {'X-Guest-Session': 'smuggled', 'Authorization': 'x'},
        ),
      );
      expect(sentHeaders()['Authorization'], 'Bearer acc', reason: path);
      expect(
        sentHeaders().containsKey('X-Guest-Session'),
        isFalse,
        reason: path,
      );
    }
  });

  test('skipAuth requests keep exactly the headers the caller set', () async {
    await tokens.save(accessToken: 'acc', refreshToken: 'ref');
    await dio.delete<void>(
      '/api/guest-sessions/current',
      options: Options(
        extra: {AuthInterceptor.skipAuth: true},
        headers: {'X-Guest-Session': _guestToken},
      ),
    );
    expect(sentHeaders()['X-Guest-Session'], _guestToken);
    expect(sentHeaders().containsKey('Authorization'), isFalse);
  });

  test('401 GUEST_SESSION_EXPIRED deletes the guest token, never refreshes '
      'or logs out the login', () async {
    FlutterSecureStorage.setMockInitialValues({
      GuestSessionStorage.key: _guestToken,
    });
    await guest.load();
    expect(guest.token, _guestToken);
    api.respond = (_) => _json(401, {
      'code': 'GUEST_SESSION_EXPIRED',
      'message': 'Your guest session has expired. Start a new one',
    });

    await expectLater(
      dio.get<void>('/api/cart'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(guest.token, isNull);
    expect(
      await const FlutterSecureStorage().read(key: GuestSessionStorage.key),
      isNull,
      reason: 'deleted from secure storage too',
    );
    expect(guestExpired, 1);
    expect(refreshApi.requests, isEmpty);
    expect(sessionExpired, 0);
    expect(api.requests, hasLength(1), reason: 'no retry');
  });

  test('an expiry for an older token does not delete a newer one', () async {
    await guest.save('old');
    api.respond = (o) {
      // A new session is stored while the old request is in flight.
      guest.save('new');
      return _json(401, {'code': 'GUEST_SESSION_EXPIRED'});
    };
    await expectLater(dio.get<void>('/api/cart'), throwsA(isA<DioException>()));
    expect(guest.token, 'new');
    expect(guestExpired, 0);
  });

  test('a plain 401 on a guest call keeps the token and does not '
      'refresh', () async {
    await guest.save(_guestToken);
    api.respond = (_) => _json(401, {'code': 'UNAUTHORIZED'});
    await expectLater(dio.get<void>('/api/cart'), throwsA(isA<DioException>()));
    expect(guest.token, _guestToken);
    expect(refreshApi.requests, isEmpty);
  });

  test(
    'logged-in 401 still refreshes once and retries with the new token',
    () async {
      await tokens.save(accessToken: 'old-access', refreshToken: 'r');
      api.respond = (o) => o.headers['Authorization'] == 'Bearer old-access'
          ? _json(401, {'code': 'UNAUTHORIZED'})
          : _json(200, {'ok': true});
      final res = await dio.get<Map<String, dynamic>>('/api/cart');
      expect(res.data, {'ok': true});
      expect(refreshApi.requests, hasLength(1));
      expect(api.requests.last.headers['Authorization'], 'Bearer new-access');
      expect(api.requests.last.headers.containsKey('X-Guest-Session'), isFalse);
    },
  );
}
