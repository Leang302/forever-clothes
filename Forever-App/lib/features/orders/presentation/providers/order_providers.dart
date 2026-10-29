import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../data/datasources/order_remote_data_source.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/khqr_payment.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

part 'order_providers.g.dart';

@Riverpod(keepAlive: true)
OrderRepository orderRepository(Ref ref) =>
    OrderRepositoryImpl(OrderRemoteDataSource(ref.watch(dioProvider)));

/// Order history of the signed-in user.
@Riverpod(keepAlive: true)
class OrdersController extends _$OrdersController {
  @override
  Future<List<Order>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.watch(orderRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(orderRepositoryProvider).list());
  }

  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
  }) async {
    final order = await ref
        .read(orderRepositoryProvider)
        .place(address: address, paymentMethod: paymentMethod);
    ref.invalidate(cartControllerProvider); // the server emptied the cart
    await refresh();
    return order;
  }

  /// The order takes its lines out of the cart until it is paid or cancelled.
  Future<KhqrPayment> startKhqr(ShippingAddress address) async {
    final payment = await ref.read(orderRepositoryProvider).startKhqr(address);
    ref.invalidate(cartControllerProvider);
    return payment;
  }

  Future<bool> verifyKhqr(int orderId) async {
    final paid = await ref.read(orderRepositoryProvider).verifyKhqr(orderId);
    if (paid) await refresh();
    return paid;
  }

  Future<bool> cancelKhqr(int orderId) async {
    final paid = await ref.read(orderRepositoryProvider).cancelKhqr(orderId);
    ref.invalidate(cartControllerProvider); // cancelling put the lines back
    if (paid) await refresh();
    return paid;
  }

  Future<void> cancel(int id) async {
    await ref.read(orderRepositoryProvider).cancel(id);
    await refresh();
  }
}
