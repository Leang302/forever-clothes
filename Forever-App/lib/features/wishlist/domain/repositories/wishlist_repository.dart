import '../../../catalog/domain/entities/product.dart';

abstract interface class WishlistRepository {
  Future<List<Product>> list();

  Future<Product> add(int productId);

  Future<void> remove(int productId);
}
