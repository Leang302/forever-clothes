import 'dart:io' show Platform;

/// Build-time configuration. Override with `--dart-define=API_BASE_URL=http://192.168.1.10:8989`.
class AppConfig {
  const AppConfig._();

  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  static const currencySymbol = r'$';
  static const prefsBaseUrlKey = 'api_base_url';

  /// Android emulators reach the host machine at 10.0.2.2; iOS simulators share localhost.
  static String get defaultBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    return Platform.isAndroid
        ? 'http://10.0.2.2:8989'
        : 'http://localhost:8989';
  }
}
