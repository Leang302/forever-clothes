import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/catalog/domain/entities/product_query.dart';
import 'package:forever_app/features/catalog/presentation/providers/catalog_providers.dart';

void main() {
  test('applied filter count includes non-blank search text', () {
    expect(const ProductQuery().appliedFilterCount, 0);
    expect(
      const ProductQuery(
        search: ' dress ',
        categories: ['Women'],
        subCategories: ['Dresses'],
      ).appliedFilterCount,
      3,
    );
    expect(const ProductQuery(search: '   ').appliedFilterCount, 0);
  });

  test('individual removal and Clear all preserve sort', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(productQueryControllerProvider.notifier);

    controller.setSearch('shirt');
    controller.setSort(ProductSort.priceDesc);
    controller.setFilters(
      categories: ['Men', 'Kids'],
      subCategories: ['Topwear', 'Winterwear'],
    );
    controller.removeCategory('Kids');
    controller.removeSubCategory('Winterwear');

    var query = container.read(productQueryControllerProvider);
    expect(query.search, 'shirt');
    expect(query.categories, ['Men']);
    expect(query.subCategories, ['Topwear']);
    expect(query.sort, ProductSort.priceDesc);

    controller.clearSearchAndFilters();
    query = container.read(productQueryControllerProvider);
    expect(query.search, isEmpty);
    expect(query.categories, isEmpty);
    expect(query.subCategories, isEmpty);
    expect(query.sort, ProductSort.priceDesc);
  });
}
