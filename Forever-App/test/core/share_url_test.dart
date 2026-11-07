import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/config/app_config.dart';

void main() {
  group('productWebUrl', () {
    test('joins base and /product/<id>', () {
      expect(
        productWebUrl(42, baseUrl: 'https://shop.test'),
        'https://shop.test/product/42',
      );
    });

    test('drops one or more trailing slashes from the base', () {
      expect(
        productWebUrl(42, baseUrl: 'https://shop.test/'),
        'https://shop.test/product/42',
      );
      expect(
        productWebUrl(42, baseUrl: 'https://shop.test///'),
        'https://shop.test/product/42',
      );
    });

    test('keeps a base path and trims whitespace', () {
      expect(
        productWebUrl(7, baseUrl: '  https://x.test/store/ '),
        'https://x.test/store/product/7',
      );
    });

    test('preserves the id exactly', () {
      expect(
        productWebUrl(1234567890, baseUrl: 'http://localhost:5173'),
        'http://localhost:5173/product/1234567890',
      );
    });

    test('defaults to AppConfig.webBaseUrl (no placeholder host)', () {
      final url = productWebUrl(5);
      expect(
        url,
        startsWith(AppConfig.webBaseUrl.replaceAll(RegExp(r'/+$'), '')),
      );
      expect(url, endsWith('/product/5'));
      expect(url, isNot(contains('example.com')));
      // Not running on Android here, so the dev default mirrors the API's.
      expect(AppConfig.webBaseUrl, 'http://localhost:5173');
    });
  });

  test('share text = name, price and link', () {
    expect(
      productShareText(
        name: 'Summer Dress',
        price: r'$25',
        productId: 9,
        baseUrl: 'https://shop.test/',
      ),
      'Summer Dress — \$25\nhttps://shop.test/product/9',
    );
  });
}
