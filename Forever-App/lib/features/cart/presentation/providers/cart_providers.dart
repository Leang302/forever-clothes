import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';

part 'cart_providers.g.dart';

@Riverpod(keepAlive: true)
CartRepository cartRepository(Ref ref) =>
    CartRepositoryImpl(CartRemoteDataSource(ref.watch(dioProvider)));

/// The signed-in user's server-side cart. Empty while logged out; reloads when the user changes.
@Riverpod(keepAlive: true)
class CartController extends _$CartController {
  @override
  Future<Cart> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Cart.empty;
    return ref.watch(cartRepositoryProvider).getCart();
  }

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  Future<void> add(int productId, String size) async {
    state = AsyncData(await _repo.add(productId: productId, size: size));
  }

  Future<void> setQuantity(CartLine line, int quantity) async {
    state = AsyncData(
      await _repo.setQuantity(
        productId: line.productId,
        size: line.size,
        quantity: quantity,
      ),
    );
  }

  Future<void> remove(CartLine line) async {
    state = AsyncData(await _repo.remove(line.id));
  }
}

@riverpod
int cartCount(Ref ref) =>
    ref.watch(cartControllerProvider).value?.itemCount ?? 0;
