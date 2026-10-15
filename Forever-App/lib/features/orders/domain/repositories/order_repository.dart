import '../entities/order.dart';

abstract interface class OrderRepository {
  /// Creates an order from the server-side cart (which the server then empties).
  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
  });

  Future<List<Order>> list();

  Future<Order> cancel(int id);
}
