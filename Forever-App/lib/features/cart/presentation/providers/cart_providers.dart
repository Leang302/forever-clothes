import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';
import 'guest_session_providers.dart';

part 'cart_providers.g.dart';

@Riverpod(keepAlive: true)
CartRepository cartRepository(Ref ref) =>
    CartRepositoryImpl(CartRemoteDataSource(ref.watch(dioProvider)));

/// The shopper's server-side cart:
///
/// * logged in: the account's cart (the interceptor sends only the login);
/// * anonymous with a guest session: that session's cart;
/// * anonymous without one: empty, and no session is created here (that
///   happens only on add-to-cart, see `addToCartWithFeedback`).
///
/// The two carts are never merged. Reloads when the user changes (login /
/// logout); resets to empty when the guest session expires.
@Riverpod(keepAlive: true)
class CartController extends _$CartController {
  @override
  Future<Cart> build() async {
    ref.listen(guestSessionExpiredProvider, (_, _) {
      if (ref.read(currentUserProvider) == null) {
        state = const AsyncData(Cart.empty);
      }
    });
    final user = ref.watch(currentUserProvider);
    // Not watched: creating the session on add-to-cart must not trigger a
    // reload racing the add (the add's response is the new state anyway).
    if (user == null && ref.read(guestSessionProvider) == null) {
      return Cart.empty;
    }
    return ref.watch(cartRepositoryProvider).getCart();
  }

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  Future<void> add(int productId, String size, {int quantity = 1}) async {
    state = AsyncData(
      await _repo.add(productId: productId, size: size, quantity: quantity),
    );
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
