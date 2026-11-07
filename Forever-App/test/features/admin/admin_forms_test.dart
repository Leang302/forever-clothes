import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/network/network_providers.dart';
import 'package:forever_app/features/admin/presentation/coupon_form_screen.dart';
import 'package:forever_app/features/admin/presentation/product_form_screen.dart';

void main() {
  late Dio dio;
  RequestOptions? saved;

  setUp(() {
    saved = null;
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method != 'GET') saved = options;
            final data = switch (options.path) {
              '/api/admin/categories' => [
                {'id': 1, 'name': 'Women'},
              ],
              '/api/admin/categories/1/sub-categories' => [
                {'id': 2, 'name': 'Dresses'},
              ],
              _ => <String, dynamic>{},
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
  });

  Future<void> showForm(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => form),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('editing a product sends the complete multipart form', (
    tester,
  ) async {
    await showForm(
      tester,
      const ProductFormScreen(
        product: {
          'id': 5,
          'name': 'Summer Dress',
          'description': 'Cotton',
          'price': 25,
          'category': 'Women',
          'subCategory': 'Dresses',
          'sizes': ['S', 'M'],
          'bestseller': false,
          'images': [],
        },
      ),
    );

    expect(find.text('Summer Dress'), findsOneWidget);
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();

    expect(saved?.path, '/api/admin/products/5');
    final fields = (saved!.data as FormData).fields;
    expect(fields.where((e) => e.key == 'category').single.value, 'Women');
    expect(fields.where((e) => e.key == 'subCategory').single.value, 'Dresses');
    expect(
      fields.where((e) => e.key == 'sizes').map((e) => e.value),
      containsAll(['S', 'M']),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a product sends stock, active and image URLs', (
    tester,
  ) async {
    await showForm(tester, const ProductFormScreen());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Linen Shirt',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Breathable',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '30');
    await tester.enterText(find.byKey(const Key('product-stock')), '7');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Women').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subcategory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dresses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('M'));
    await tester.ensureVisible(find.byKey(const Key('product-active')));
    await tester.tap(find.byKey(const Key('product-active')));
    await tester.pump();

    // A non-http URL is rejected, an https one is accepted.
    await tester.ensureVisible(find.byKey(const Key('product-image-url')));
    await tester.enterText(
      find.byKey(const Key('product-image-url')),
      'ftp://x.test/a.png',
    );
    await tester.tap(find.byKey(const Key('product-add-image-url')));
    await tester.pump();
    expect(
      find.text('Image URLs must start with http:// or https://'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('product-image-url')),
      'https://img.test/shirt.png',
    );
    await tester.tap(find.byKey(const Key('product-add-image-url')));
    await tester.pump();

    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();

    expect(saved?.path, '/api/admin/products');
    expect(saved?.method, 'POST');
    final fields = (saved!.data as FormData).fields;
    String one(String k) => fields.where((e) => e.key == k).single.value;
    expect(one('stock'), '7');
    expect(one('active'), 'false');
    expect(one('imageUrls'), 'https://img.test/shirt.png');
    expect(one('name'), 'Linen Shirt');
    expect(tester.takeException(), isNull);
  });

  test('validateImageUrl enforces http(s) and the 4-image limit', () {
    expect(validateImageUrl('https://a.test/x.png'), isNull);
    expect(validateImageUrl('http://a.test/x.png'), isNull);
    expect(validateImageUrl(''), isNotNull);
    expect(validateImageUrl('a.test/x.png'), isNotNull);
    expect(validateImageUrl('javascript:alert(1)'), isNotNull);
    expect(
      validateImageUrl(
        'https://a.test/x.png',
        existing: ['https://a.test/x.png'],
      ),
      isNotNull,
    );
    expect(validateImageUrl('https://a.test/y.png', total: 4), isNotNull);
  });

  testWidgets('creating a coupon sends its discount settings', (tester) async {
    await showForm(tester, const CouponFormScreen());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Code'),
      'WELCOME10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Percent off (1–90)'),
      '10',
    );
    await tester.ensureVisible(find.text('Save coupon'));
    await tester.tap(find.text('Save coupon'));
    await tester.pumpAndSettle();

    expect(saved?.path, '/api/admin/coupons');
    expect((saved!.data as Map)['code'], 'WELCOME10');
    expect((saved!.data as Map)['percentOff'], 10);
    expect(tester.takeException(), isNull);
  });
}
