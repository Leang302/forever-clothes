import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/widgets/choice_chip_pill.dart';
import 'package:forever_app/features/cart/data/models/cart_dto.dart';
import 'package:forever_app/features/catalog/data/models/product_dto.dart';
import 'package:forever_app/features/catalog/domain/entities/product.dart';
import 'package:forever_app/features/catalog/domain/entities/stock.dart';
import 'package:forever_app/features/catalog/presentation/widgets/stock_widgets.dart';

Map<String, dynamic> _json({
  Map<String, int>? stock,
  bool? inStock,
  bool active = true,
}) => {
  'id': 7,
  'name': 'Tee',
  'description': 'd',
  'price': 20,
  'category': 'Men',
  'subCategory': 'Topwear',
  'sizes': ['S', 'M', 'L'],
  'images': <String>[],
  'bestseller': false,
  'active': active,
  'stock': ?stock,
  'inStock': ?inStock,
};

void main() {
  group('product DTO stock parsing', () {
    test('maps per-size stock (keeping size order) and inStock', () {
      final p = ProductDto.fromJson(
        _json(stock: {'S': 0, 'M': 3, 'L': 12}, inStock: true),
      ).toEntity();
      expect(p.stock, {'S': 0, 'M': 3, 'L': 12});
      expect(p.stock.keys.toList(), ['S', 'M', 'L']);
      expect(p.inStock, isTrue);
      expect(p.stockOf('S'), 0);
      expect(p.stockOf('M'), 3);
      expect(p.isSizeAvailable('S'), isFalse);
      expect(p.availableSizes, ['M', 'L']);
      expect(p.canBuy, isTrue);
    });

    test('inStock false (inactive or all zero) makes nothing buyable', () {
      final p = ProductDto.fromJson(
        _json(stock: {'S': 0, 'M': 0, 'L': 0}, inStock: false),
      ).toEntity();
      expect(p.inStock, isFalse);
      expect(p.availableSizes, isEmpty);
      expect(p.canBuy, isFalse);
    });

    test(
      'inactive product with stock left is not buyable (active != stock)',
      () {
        final p = ProductDto.fromJson(
          _json(stock: {'S': 5, 'M': 5, 'L': 5}, inStock: false, active: false),
        ).toEntity();
        expect(p.stockOf('S'), 5);
        expect(p.isSizeAvailable('S'), isFalse);
        expect(p.canBuy, isFalse);
      },
    );

    test('older payload without stock falls back to "ask the server"', () {
      final p = ProductDto.fromJson(_json()).toEntity();
      expect(p.stock, isEmpty);
      expect(p.inStock, isTrue);
      expect(p.stockOf('M'), StockRules.maxPerLine);
      expect(p.canBuy, isTrue);
    });

    test('cart line JSON carries the size stock', () {
      final cart = CartDto.fromJson({
        'items': [
          {
            'id': 1,
            'productId': 7,
            'name': 'Tee',
            'price': 20,
            'size': 'M',
            'quantity': 5,
            'stock': 3,
          },
          {
            'id': 2,
            'productId': 8,
            'name': 'Cap',
            'price': 5,
            'size': 'S',
            'quantity': 1,
          },
        ],
        'itemCount': 6,
        'subtotal': 105,
        'deliveryFee': 10,
        'total': 115,
      }).toEntity();
      final over = cart.items.first;
      expect(over.stock, 3);
      expect(over.exceedsStock, isTrue);
      expect(over.maxQuantity, 3);
      expect(cart.items.last.stock, isNull);
      expect(cart.items.last.exceedsStock, isFalse);
      expect(cart.items.last.maxQuantity, StockRules.maxPerLine);
      expect(cart.problemLines.map((l) => l.id), [1]);
      expect(cart.hasStockProblems, isTrue);
    });
  });

  group('stock clamping', () {
    test('max quantity is the stock, capped at 99, 0 when sold out', () {
      expect(StockRules.maxQuantity(0), 0);
      expect(StockRules.maxQuantity(-2), 0);
      expect(StockRules.maxQuantity(3), 3);
      expect(StockRules.maxQuantity(99), 99);
      expect(StockRules.maxQuantity(250), 99);
    });

    test('clampQuantity keeps 1..max', () {
      expect(StockRules.clampQuantity(5, 3), 3);
      expect(StockRules.clampQuantity(0, 3), 1);
      expect(StockRules.clampQuantity(2, 3), 2);
      expect(StockRules.clampQuantity(150, 500), 99);
      expect(StockRules.clampQuantity(4, 0), 0);
    });

    test('labels: In stock / Only N left (N <= 5) / Out of stock', () {
      expect(StockRules.label(0), 'Out of stock');
      expect(StockRules.label(1), 'Only 1 left');
      expect(StockRules.label(5), 'Only 5 left');
      expect(StockRules.label(6), 'In stock');
    });
  });

  testWidgets('sold-out sizes are shown but cannot be selected', (
    tester,
  ) async {
    const product = Product(
      id: 7,
      name: 'Tee',
      description: 'd',
      price: 20,
      category: 'Men',
      subCategory: 'Topwear',
      sizes: ['S', 'M'],
      images: [],
      bestseller: false,
      stock: {'S': 0, 'M': 2},
    );
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                SizeSelector(
                  product: product,
                  selected: picked,
                  onSelected: (s) => setState(() => picked = s),
                ),
                StockStatus(product: product, size: picked),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('size-S')), findsOneWidget);
    expect(
      tester.widget<PillChip>(find.byKey(const Key('size-S'))).enabled,
      isFalse,
    );
    expect(find.text('In stock'), findsOneWidget); // overall, before picking

    await tester.tap(find.byKey(const Key('size-S')));
    await tester.pump();
    expect(picked, isNull);

    await tester.tap(find.byKey(const Key('size-M')));
    await tester.pump();
    expect(picked, 'M');
    expect(find.text('Only 2 left'), findsOneWidget);
  });
}
