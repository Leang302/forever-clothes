import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT pair persisted in the platform keychain/keystore, with a synchronous in-memory copy for interceptors.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  Future<void> load() async {
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (_) {
      // Keychain unavailable: start logged out.
    }
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    try {
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
    } catch (_) {}
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }
}
