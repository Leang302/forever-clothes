import '../entities/catalog_filters.dart';
import '../entities/paged_result.dart';
import '../entities/product.dart';
import '../entities/product_query.dart';

abstract interface class CatalogRepository {
  Future<PagedResult<Product>> search(
    ProductQuery query, {
    int page = 0,
    int size = 20,
  });

  Future<CatalogFilters> filters();

  Future<List<Product>> latest({int limit = 10});

  Future<List<Product>> bestsellers({int limit = 5});

  Future<Product> product(int id);

  Future<List<Product>> related(int id, {int limit = 5});
}
