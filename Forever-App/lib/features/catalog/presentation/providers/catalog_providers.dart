import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/catalog_remote_data_source.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/paged_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/repositories/catalog_repository.dart';

part 'catalog_providers.g.dart';

@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) =>
    CatalogRepositoryImpl(CatalogRemoteDataSource(ref.watch(dioProvider)));

@riverpod
Future<List<Product>> latestProducts(Ref ref) =>
    ref.watch(catalogRepositoryProvider).latest(limit: 10);

@riverpod
Future<List<Product>> bestSellers(Ref ref) =>
    ref.watch(catalogRepositoryProvider).bestsellers(limit: 6);

@riverpod
Future<Product> productDetail(Ref ref, int id) =>
    ref.watch(catalogRepositoryProvider).product(id);

@riverpod
Future<List<Product>> relatedProducts(Ref ref, int id) =>
    ref.watch(catalogRepositoryProvider).related(id);

@Riverpod(keepAlive: true)
Future<CatalogFilters> catalogFilters(Ref ref) =>
    ref.watch(catalogRepositoryProvider).filters();

/// Search text, category/type filters and sort of the Collection tab. Kept alive so the Home screen
/// can preset a category before the tab is first opened.
@Riverpod(keepAlive: true)
class ProductQueryController extends _$ProductQueryController {
  @override
  ProductQuery build() => const ProductQuery();

  void setSearch(String value) => state = state.copyWith(search: value);

  void setSort(ProductSort sort) => state = state.copyWith(sort: sort);

  void setFilters({
    required List<String> categories,
    required List<String> subCategories,
  }) => state = state.copyWith(
    categories: categories,
    subCategories: subCategories,
  );

  void removeCategory(String category) => state = state.copyWith(
    categories: state.categories.where((value) => value != category).toList(),
  );

  void removeSubCategory(String subCategory) => state = state.copyWith(
    subCategories: state.subCategories
        .where((value) => value != subCategory)
        .toList(),
  );

  /// Matches the web collection's "Clear all": preserve the chosen sort.
  void clearSearchAndFilters() => state = state.copyWith(
    search: '',
    categories: const [],
    subCategories: const [],
  );

  /// Single-category shortcut used by the Home chips; null clears the category.
  void selectCategory(String? category) => state = state.copyWith(
    categories: category == null ? const [] : [category],
    subCategories: const [],
  );

  void reset() => state = const ProductQuery();
}

/// Paginated results for the current [ProductQuery]. Rebuilds from page 0 whenever the query changes.
@Riverpod(keepAlive: true)
class ProductList extends _$ProductList {
  bool _loadingMore = false;

  @override
  Future<PagedResult<Product>> build() {
    final query = ref.watch(productQueryControllerProvider);
    return ref.watch(catalogRepositoryProvider).search(query);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLast || _loadingMore) return;
    _loadingMore = true;
    try {
      final query = ref.read(productQueryControllerProvider);
      final next = await ref
          .read(catalogRepositoryProvider)
          .search(query, page: current.page + 1);
      state = AsyncData(
        next.copyWith(items: [...current.items, ...next.items]),
      );
    } finally {
      _loadingMore = false;
    }
  }
}
