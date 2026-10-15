import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/paged_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';
import '../models/filters_dto.dart';
import '../models/product_dto.dart';
import '../models/product_page_dto.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._remote);

  final CatalogRemoteDataSource _remote;

  @override
  Future<PagedResult<Product>> search(
    ProductQuery query, {
    int page = 0,
    int size = 20,
  }) async {
    final dto = await _remote.search(
      search: query.search,
      categories: query.categories,
      subCategories: query.subCategories,
      sort: query.sort.apiValue,
      page: page,
      size: size,
    );
    return dto.toEntity();
  }

  @override
  Future<CatalogFilters> filters() async =>
      (await _remote.filters()).toEntity();

  @override
  Future<List<Product>> latest({int limit = 10}) async =>
      _map(await _remote.latest(limit));

  @override
  Future<List<Product>> bestsellers({int limit = 5}) async =>
      _map(await _remote.bestsellers(limit));

  @override
  Future<Product> product(int id) async =>
      (await _remote.product(id)).toEntity();

  @override
  Future<List<Product>> related(int id, {int limit = 5}) async =>
      _map(await _remote.related(id, limit));

  List<Product> _map(List<ProductDto> dtos) =>
      dtos.map((e) => e.toEntity()).toList();
}
