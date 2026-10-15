import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_remote_data_source.dart';
import '../models/cart_dto.dart';

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._remote);

  final CartRemoteDataSource _remote;

  @override
  Future<Cart> getCart() async => (await _remote.get()).toEntity();

  @override
  Future<Cart> add({required int productId, required String size}) async =>
      (await _remote.add(productId, size)).toEntity();

  @override
  Future<Cart> setQuantity({
    required int productId,
    required String size,
    required int quantity,
  }) async => (await _remote.setQuantity(productId, size, quantity)).toEntity();

  @override
  Future<Cart> remove(int lineId) async =>
      (await _remote.remove(lineId)).toEntity();
}
