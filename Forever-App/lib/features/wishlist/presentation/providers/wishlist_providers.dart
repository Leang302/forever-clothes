import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../data/datasources/wishlist_remote_data_source.dart';
import '../../data/repositories/wishlist_repository_impl.dart';
import '../../domain/repositories/wishlist_repository.dart';

part 'wishlist_providers.g.dart';

@Riverpod(keepAlive: true)
WishlistRepository wishlistRepository(Ref ref) =>
    WishlistRepositoryImpl(WishlistRemoteDataSource(ref.watch(dioProvider)));

/// The signed-in user's saved products. Empty while logged out; reloads when the user changes.
@Riverpod(keepAlive: true)
class WishlistController extends _$WishlistController {
  @override
  Future<List<Product>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.watch(wishlistRepositoryProvider).list();
  }

  WishlistRepository get _repo => ref.read(wishlistRepositoryProvider);

  bool contains(int productId) =>
      state.value?.any((p) => p.id == productId) ?? false;

  Future<void> toggle(Product product) async {
    final current = state.value ?? const [];
    if (current.any((p) => p.id == product.id)) {
      await _repo.remove(product.id);
      state = AsyncData(current.where((p) => p.id != product.id).toList());
    } else {
      final saved = await _repo.add(product.id);
      state = AsyncData([saved, ...current]);
    }
  }
}
