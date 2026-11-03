import '../../../catalog/data/models/product_dto.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../domain/repositories/wishlist_repository.dart';
import '../datasources/wishlist_remote_data_source.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl(this._remote);

  final WishlistRemoteDataSource _remote;

  @override
  Future<List<Product>> list() async =>
      (await _remote.list()).map((e) => e.toEntity()).toList();

  @override
  Future<Product> add(int productId) async =>
      (await _remote.add(productId)).toEntity();

  @override
  Future<void> remove(int productId) => _remote.remove(productId);
}
