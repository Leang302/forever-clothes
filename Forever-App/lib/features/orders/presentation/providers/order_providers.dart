import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Shipping methods offered at checkout.
@riverpod
Future<List<ShippingOption>> checkoutOptions(Ref ref) =>
    ref.watch(orderRepositoryProvider).checkoutOptions();

/// Access tokens (`guestAccessToken`) of the guest orders placed in THIS app
/// run, by order id.
///
/// Deliberately memory-only — never persisted, logged, or put in a route —
/// so on a shared device a later user can't open a previous guest's order:
/// after an app restart (or a login/logout) they are gone and the shopper
/// relies on the confirmation e-mail instead.
@Riverpod(keepAlive: true)
class GuestOrderAccess extends _$GuestOrderAccess {
  @override
  Map<int, String> build() {
    // Any login/logout forgets them.
    ref.watch(currentUserProvider.select((u) => u?.id));
    return const {};
  }

  void remember(int orderId, String accessToken) =>
      state = {...state, orderId: accessToken};

  String? tokenFor(int orderId) => state[orderId];
}

/// One order, by id: the signed-in user's own (account endpoints), or a
/// guest order placed in this app run (via its in-memory access token).
@riverpod
Future<Order> orderDetail(Ref ref, int orderId) {
  final repo = ref.watch(orderRepositoryProvider);
  final guestAccess = ref.watch(
    guestOrderAccessProvider.select((m) => m[orderId]),
  );
  return guestAccess != null
      ? repo.getGuestOrder(orderId, guestAccess)
      : repo.getById(orderId);
}

/// Order history of the signed-in user (guests have none: their orders are
/// reachable only through the in-memory [GuestOrderAccess] tokens).
@Riverpod(keepAlive: true)
class OrdersController extends _$OrdersController {
  @override
  Future<List<Order>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.watch(orderRepositoryProvider).list();
  }

  OrderRepository get _repo => ref.read(orderRepositoryProvider);

  bool get _signedIn => ref.read(currentUserProvider) != null;

  Future<void> refresh() async {
    if (!_signedIn) {
      state = const AsyncData([]);
      return;
    }
    state = AsyncData(await _repo.list());
  }

  void _rememberGuestAccess(int orderId, String? accessToken) {
    if (accessToken == null) return;
    ref.read(guestOrderAccessProvider.notifier).remember(orderId, accessToken);
  }

  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
    String? idempotencyKey,
  }) async {
    final placed = await _repo.place(
      address: address,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      shippingMethod: shippingMethod,
      cartItemIds: cartItemIds,
      idempotencyKey: idempotencyKey,
    );
    _rememberGuestAccess(placed.order.id, placed.guestAccessToken);
    ref.invalidate(cartControllerProvider); // the server emptied the cart
    await refresh();
    return placed.order;
  }

  /// The order takes its lines out of the cart until it is paid or cancelled.
  Future<KhqrPayment> startKhqr(
    ShippingAddress address, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
    String? idempotencyKey,
  }) async {
    final payment = await _repo.startKhqr(
      address,
      couponCode: couponCode,
      shippingMethod: shippingMethod,
      cartItemIds: cartItemIds,
      idempotencyKey: idempotencyKey,
    );
    _rememberGuestAccess(payment.orderId, payment.guestAccessToken);
    ref.invalidate(cartControllerProvider);
    return payment;
  }

  String? _guestToken(int orderId) =>
      ref.read(guestOrderAccessProvider.notifier).tokenFor(orderId);

  Future<bool> verifyKhqr(int orderId) async {
    final token = _guestToken(orderId);
    final paid = token != null
        ? await _repo.verifyGuestKhqr(orderId, token)
        : await _repo.verifyKhqr(orderId);
    if (paid) await refresh();
    return paid;
  }

  Future<bool> cancelKhqr(int orderId) async {
    final token = _guestToken(orderId);
    final paid = token != null
        ? await _repo.cancelGuestKhqr(orderId, token)
        : await _repo.cancelKhqr(orderId);
    ref.invalidate(cartControllerProvider); // cancelling put the lines back
    if (paid) await refresh();
    return paid;
  }

  Future<void> cancel(int id) async {
    final token = _guestToken(id);
    if (token != null) {
      await _repo.cancelGuestOrder(id, token);
    } else {
      await _repo.cancel(id);
    }
    await refresh();
  }
}
