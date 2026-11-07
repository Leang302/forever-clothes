import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The anonymous cart session's opaque token (`X-Guest-Session`), persisted in
/// the platform keychain/keystore under its OWN key — separate from the login
/// tokens in `TokenStorage` — so a guest cart survives app restarts while the
/// server-side session is valid. A synchronous in-memory copy serves the
/// network interceptor.
///
/// This is never a login: holding a guest token does not make anyone "signed in".
class GuestSessionStorage {
  GuestSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'guest_session_token';

  final FlutterSecureStorage _storage;
  String? _token;

  String? get token => _token;

  Future<void> load() async {
    try {
      _token = await _storage.read(key: key);
    } catch (_) {
      // Keychain unavailable: start without a guest cart.
    }
  }

  Future<void> save(String token) async {
    _token = token;
    try {
      await _storage.write(key: key, value: token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _token = null;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
