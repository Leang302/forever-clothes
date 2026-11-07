import 'dart:io' show Platform;

/// Build-time configuration.
///
/// - `--dart-define=API_BASE_URL=http://192.168.1.10:8989` — the Spring API.
/// - `--dart-define=WEB_BASE_URL=https://shop.your-domain.tld` — the public
///   React storefront, used for shared product links. **Real recipients need
///   this**: the dev default below only resolves on the developer's machine
///   (or the Android emulator), so release builds must pass the deployed URL.
class AppConfig {
  const AppConfig._();

  static const _fromEnv = String.fromEnvironment('API_BASE_URL');
  static const _webFromEnv = String.fromEnvironment('WEB_BASE_URL');

  static const currencySymbol = r'$';
  static const prefsBaseUrlKey = 'api_base_url';

  /// Android emulators reach the host machine at 10.0.2.2; iOS simulators share localhost.
  static String get defaultBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    return Platform.isAndroid
        ? 'http://10.0.2.2:8989'
        : 'http://localhost:8989';
  }

  /// Origin of the React storefront (which serves `/product/:id` with Open
  /// Graph tags). Defaults to the local Vite dev server, mirroring
  /// [defaultBaseUrl]; override with `WEB_BASE_URL` for anything shared with
  /// other people.
  static String get webBaseUrl {
    if (_webFromEnv.isNotEmpty) return _webFromEnv;
    return Platform.isAndroid
        ? 'http://10.0.2.2:5173'
        : 'http://localhost:5173';
  }
}

/// Public web link for a product: `<webBaseUrl>/product/<id>`.
///
/// Trailing slashes on the base are dropped so the result never contains `//`
/// before `product`. [baseUrl] defaults to [AppConfig.webBaseUrl].
String productWebUrl(int productId, {String? baseUrl}) {
  final base = (baseUrl ?? AppConfig.webBaseUrl).trim().replaceAll(
    RegExp(r'/+$'),
    '',
  );
  return '$base/product/$productId';
}

/// Text handed to the OS share sheet: name, price and the product link.
String productShareText({
  required String name,
  required String price,
  required int productId,
  String? baseUrl,
}) => '$name — $price\n${productWebUrl(productId, baseUrl: baseUrl)}';
