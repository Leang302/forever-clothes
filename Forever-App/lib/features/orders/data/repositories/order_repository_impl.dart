import '../../domain/entities/khqr_payment.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/order_dto.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._remote);

  final OrderRemoteDataSource _remote;

  @override
  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
  }) async => (await _remote.place(
    AddressDto.fromEntity(address),
    paymentMethod.apiValue,
  )).toEntity();

  @override
  Future<List<Order>> list() async =>
      (await _remote.list()).map((e) => e.toEntity()).toList();

  @override
  Future<Order> cancel(int id) async => (await _remote.cancel(id)).toEntity();

  @override
  Future<KhqrPayment> startKhqr(ShippingAddress address) =>
      _remote.khqrCheckout(AddressDto.fromEntity(address));

  @override
  Future<bool> verifyKhqr(int orderId) => _remote.verifyKhqr(orderId);

  @override
  Future<bool> cancelKhqr(int orderId) => _remote.cancelKhqr(orderId);
}
