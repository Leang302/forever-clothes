import '../../domain/entities/khqr_payment.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/checkout_options_dto.dart';
import '../models/order_dto.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._remote);

  final OrderRemoteDataSource _remote;

  @override
  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  }) async => (await _remote.place(
    AddressDto.fromEntity(address),
    paymentMethod.apiValue,
    couponCode: couponCode,
    shippingMethod: shippingMethod,
    cartItemIds: cartItemIds,
  )).toEntity();

  @override
  Future<List<Order>> list() async =>
      (await _remote.list()).map((e) => e.toEntity()).toList();

  @override
  Future<Order> getById(int id) async => (await _remote.get(id)).toEntity();

  @override
  Future<Order> cancel(int id) async => (await _remote.cancel(id)).toEntity();

  @override
  Future<KhqrPayment> startKhqr(
    ShippingAddress address, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  }) => _remote.khqrCheckout(
    AddressDto.fromEntity(address),
    couponCode: couponCode,
    shippingMethod: shippingMethod,
    cartItemIds: cartItemIds,
  );

  @override
  Future<bool> verifyKhqr(int orderId) => _remote.verifyKhqr(orderId);

  @override
  Future<bool> cancelKhqr(int orderId) => _remote.cancelKhqr(orderId);

  @override
  Future<List<ShippingOption>> checkoutOptions() async =>
      (await _remote.checkoutOptions()).shippingMethods
          .map((e) => e.toEntity())
          .toList();

  @override
  Future<CouponPreview> checkCoupon(String code, double subtotal) async =>
      (await _remote.checkCoupon(code, subtotal)).toEntity();
}
