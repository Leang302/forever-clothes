import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/catalog/data/models/product_page_dto.dart';

void main() {
  test(
    'product page JSON maps to domain entities (ints and doubles for price)',
    () {
      final dto = ProductPageDto.fromJson({
        'content': [
          {
            'id': 1,
            'name': 'Top',
            'description': 'd',
            'price': 100,
            'category': 'Women',
            'subCategory': 'Topwear',
            'sizes': ['S', 'M'],
            'images': ['http://x/a.png'],
            'bestseller': true,
          },
          {
            'id': 2,
            'name': 'Tee',
            'description': 'd',
            'price': 19.99,
            'category': 'Men',
            'subCategory': 'Topwear',
            'sizes': ['L'],
            'images': <String>[],
          },
        ],
        'page': 0,
        'last': false,
        'totalElements': 52,
      });

      final page = dto.toEntity();
      expect(page.total, 52);
      expect(page.isLast, isFalse);
      expect(page.items.first.price, 100.0);
      expect(page.items.first.cover, 'http://x/a.png');
      expect(page.items.last.price, 19.99);
      expect(page.items.last.cover, isNull);
      expect(page.items.last.bestseller, isFalse); // default when absent
    },
  );
}
