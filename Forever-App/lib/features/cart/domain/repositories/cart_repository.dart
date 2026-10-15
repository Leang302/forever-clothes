import '../entities/cart.dart';

abstract interface class CartRepository {
  Future<Cart> getCart();

  Future<Cart> add({required int productId, required String size});

  /// A quantity of 0 removes the line.
  Future<Cart> setQuantity({
    required int productId,
    required String size,
    required int quantity,
  });

  Future<Cart> remove(int lineId);
}
