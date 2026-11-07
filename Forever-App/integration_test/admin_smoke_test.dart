// Admin smoke test driving the real app UI against the real local API.
//   flutter test integration_test/admin_smoke_test.dart -d <device-id>
// Logs in as the seeded admin through the login screen, checks the product
// list shows stock + status, creates a product through the form (image URL +
// stock + inactive), verifies it server-side, deletes it through the UI, and
// opens an order's details (customer, items, per-item subtotal, address).
// Any product it created is removed again in tearDownAll even on failure.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/admin/presentation/admin_screen.dart';
import 'package:forever_app/features/admin/presentation/product_form_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

late Dio admin;
final name = 'IT Admin Smoke ${DateTime.now().millisecondsSinceEpoch}';
const imageUrl = '$apiBase/api/media/seed/p_img1.png';

Future<List<Map<String, dynamic>>> findByName(String q) async {
  final res = (await admin.get<Map<String, dynamic>>(
    '/api/admin/products',
    queryParameters: {'q': q, 'size': 20},
  )).data!;
  return (res['content'] as List).cast<Map<String, dynamic>>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => admin = await adminDio());

  tearDownAll(() async {
    for (final p in await findByName(name)) {
      await admin.delete<void>('/api/admin/products/${p['id']}');
    }
  });

  testWidgets('admin: stock/status list, create inactive product, delete', (
    tester,
  ) async {
    await launchApp(tester, fresh: true);
    await pumpFor(tester, const Duration(seconds: 2));
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/login');
    await pumpUntil(tester, find.text('Log in'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'admin@forever.com');
    await tester.enterText(fields.at(1), 'Admin@12345');
    await tester.tap(find.text('Log in').last);
    await pumpUntil(tester, find.byType(AdminScreen));

    // Product list: stock and status per row.
    GoRouter.of(tester.element(find.byType(AdminScreen))).go('/admin/products');
    await pumpUntil(tester, byKeyPrefix('admin-stock-'));
    expect(find.textContaining(' in stock · '), findsWidgets);
    expect(
      find.text('Visible').evaluate().length +
          find.text('Hidden').evaluate().length,
      greaterThan(0),
    );
    expect(
      find.text('In stock').evaluate().length +
          find.text('Out of stock').evaluate().length,
      greaterThan(0),
    );

    // Create: name, description, price, stock, category, size, inactive,
    // image URL.
    await tester.tap(find.byType(FloatingActionButton));
    await pumpUntil(tester, find.byType(ProductFormScreen));
    await pumpFor(tester, const Duration(seconds: 1)); // categories load
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Created by the admin smoke test',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '12.5');
    await tester.enterText(find.byKey(const Key('product-stock')), '6');
    await tester.tap(find.text('Category'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Men').last);
    await pumpFor(tester, const Duration(seconds: 1)); // sub-categories load
    await tester.ensureVisible(find.text('Subcategory'));
    await tester.tap(find.text('Subcategory'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Topwear').last);
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'M'));
    await tester.tap(find.widgetWithText(FilterChip, 'M'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('product-active')));
    await tester.tap(find.byKey(const Key('product-active')));
    await tester.pump();
    expect(find.text('Hidden from shoppers (inactive)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('product-image-url')));
    await tester.enterText(
      find.byKey(const Key('product-image-url')),
      imageUrl,
    );
    await tester.tap(find.byKey(const Key('product-add-image-url')));
    await tester.pump();
    expect(find.text(imageUrl), findsOneWidget);
    await tester.tap(find.text('Save product'));
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (find.byType(ProductFormScreen).evaluate().isNotEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ProductFormScreen), findsNothing, reason: 'saved');

    // Server-side: inactive, stock 6 for M, image URL kept.
    final created = await findByName(name);
    expect(created, hasLength(1));
    final p = created.single;
    expect(p['active'], isFalse);
    expect(p['stock'], {'M': 6});
    expect(p['inStock'], isFalse, reason: 'inactive is never buyable');
    expect(p['images'], [imageUrl]);
    expect(p['price'], 12.5);

    // The list shows it (newest first) as Hidden with its stock.
    await pumpUntil(tester, find.text(name));
    expect(find.byKey(Key('admin-stock-${p['id']}')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(Key('admin-stock-${p['id']}'))).data,
      '6 in stock · M 6',
    );

    // Make it visible from the list's switch (status toggle), so the delete
    // below has an observable effect.
    final tile = find.ancestor(
      of: find.text(name),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    Future<void> waitServer(bool active) async {
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(end)) {
        await pumpFor(tester, const Duration(milliseconds: 500));
        if ((await findByName(name)).single['active'] == active) return;
      }
      fail('product active never became $active');
    }

    await waitServer(true);
    final publicVisible = await Dio(
      BaseOptions(validateStatus: (_) => true),
    ).get<Object?>('$apiBase/api/products/${p['id']}');
    expect(publicVisible.statusCode, 200);

    // Delete through the UI. The API's delete is a soft delete (it hides the
    // product so past orders keep their snapshot), so afterwards the row
    // stays in the admin list as Hidden and shoppers can't see it.
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('More actions')),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Delete').last);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(
      find.textContaining('Shoppers will no longer see it'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, find.text('"$name" removed from the shop'));
    await waitServer(false);
    expect(
      find.descendant(of: tile, matching: find.text('Hidden')),
      findsOneWidget,
    );
    final publicGet = await Dio(
      BaseOptions(validateStatus: (_) => true),
    ).get<Object?>('$apiBase/api/products/${p['id']}');
    expect(publicGet.statusCode, 404);

    // Orders: list shows customer + phone; details show items with
    // per-item subtotals and the shipping address.
    GoRouter.of(tester.element(find.byType(AdminScreen))).go('/admin/orders');
    await pumpUntil(tester, byKeyPrefix('admin-order-customer-'));
    await tester.tap(byKeyPrefix('admin-order-customer-').first);
    await pumpUntil(tester, find.text('Shipping address'));
    expect(byKeyPrefix('admin-item-subtotal-'), findsWidgets);
    expect(find.text('Items'), findsWidgets); // heading + summary line
    expect(tester.takeException(), isNull);
  });
}
