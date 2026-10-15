import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/catalog/domain/entities/catalog_filters.dart';
import 'package:forever_app/features/catalog/domain/entities/paged_result.dart';
import 'package:forever_app/features/catalog/domain/entities/product.dart';
import 'package:forever_app/features/catalog/domain/entities/product_query.dart';
import 'package:forever_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:forever_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:forever_app/features/catalog/presentation/screens/collection_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const ProductQuery()));

  testWidgets('shows removable active filters and Clear all preserves sort', (
    tester,
  ) async {
    final repository = MockCatalogRepository();
    when(() => repository.filters()).thenAnswer(
      (_) async => const CatalogFilters(
        categories: ['Men', 'Women', 'Kids'],
        subCategories: ['Topwear', 'Dresses'],
      ),
    );
    when(() => repository.search(any(), page: any(named: 'page'))).thenAnswer(
      (_) async => const PagedResult<Product>(
        items: [],
        page: 0,
        isLast: true,
        total: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: CollectionScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionScreen)),
    );
    final controller = container.read(productQueryControllerProvider.notifier);
    controller.setSort(ProductSort.priceDesc);
    controller.setFilters(categories: ['Women'], subCategories: ['Dresses']);
    await tester.enterText(find.byType(TextField), 'dress');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-filter-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active-filter-category-Women')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active-filter-sub-category-Dresses')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('open-filters')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active-filter-sub-category-Dresses')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('active-filter-sub-category-Dresses')),
      findsNothing,
    );

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    final query = container.read(productQueryControllerProvider);
    expect(query.search, isEmpty);
    expect(query.categories, isEmpty);
    expect(query.subCategories, isEmpty);
    expect(query.sort, ProductSort.priceDesc);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
