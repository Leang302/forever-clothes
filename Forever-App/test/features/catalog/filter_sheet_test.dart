import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/catalog/domain/entities/catalog_filters.dart';
import 'package:forever_app/features/catalog/domain/entities/product_query.dart';
import 'package:forever_app/features/catalog/presentation/widgets/filter_sheet.dart';

const _options = CatalogFilters(
  categories: ['Men', 'Women', 'Kids'],
  subCategories: ['Topwear', 'Bottomwear', 'Winterwear'],
);

void main() {
  Future<void> pumpLauncher(
    WidgetTester tester, {
    CatalogFilters options = _options,
    ProductQuery current = const ProductQuery(),
    TextScaler textScaler = TextScaler.noScaling,
    required ValueChanged<FilterSelection?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey('launch-filters'),
                onPressed: () async => onResult(
                  await showFilterSheet(
                    context,
                    options: options,
                    current: current,
                  ),
                ),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('launch-filters')));
    await tester.pumpAndSettle();
  }

  testWidgets('stages multi-select changes and applies them in API order', (
    tester,
  ) async {
    FilterSelection? result;
    await pumpLauncher(
      tester,
      current: const ProductQuery(
        categories: ['Men'],
        subCategories: ['Winterwear'],
      ),
      onResult: (value) => result = value,
    );

    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('SUB CATEGORY'), findsOneWidget);
    expect(find.text('2 filters selected'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('category-Men')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('category-Women')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('sub-category-Topwear')),
    );
    await tester.tap(find.byKey(const ValueKey('sub-category-Topwear')));
    await tester.pump();
    expect(find.text('4 filters selected'), findsOneWidget);

    await tester.tap(find.text('Apply (4)'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.categories, ['Men', 'Women']);
    expect(result!.subCategories, ['Topwear', 'Winterwear']);
  });

  testWidgets('Clear resets the draft without dismissing the sheet', (
    tester,
  ) async {
    FilterSelection? result;
    await pumpLauncher(
      tester,
      current: const ProductQuery(
        categories: ['Kids', 'Retired'],
        subCategories: ['Bottomwear', 'Archived'],
      ),
      onResult: (value) => result = value,
    );

    // Selections removed from the latest API options are not counted or kept.
    expect(find.text('2 filters selected'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('No filters selected'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('category-Kids')))
          .value,
      isFalse,
    );

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result!.categories, isEmpty);
    expect(result!.subCategories, isEmpty);
  });

  testWidgets('long dynamic option lists remain scrollable on a small screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final options = CatalogFilters(
      categories: List.generate(20, (index) => 'Category $index'),
      subCategories: List.generate(10, (index) => 'Type $index'),
    );

    for (final size in const [Size(320, 500), Size(500, 320)]) {
      tester.view.physicalSize = size;
      await pumpLauncher(
        tester,
        options: options,
        textScaler: const TextScaler.linear(2),
        onResult: (_) {},
      );
      expect(tester.takeException(), isNull, reason: 'viewport $size');

      final lastType = find.byKey(const ValueKey('sub-category-Type 9'));
      await tester.ensureVisible(lastType);
      await tester.pumpAndSettle();

      expect(lastType, findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');

      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
    }
  });
}
