import '../entities/khqr_payment.dart';
import '../entities/order.dart';

abstract interface class OrderRepository {
  /// Creates an order from the server-side cart (which the server then empties).
  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
  });

  Future<List<Order>> list();

  Future<Order> cancel(int id);

  /// Creates an order awaiting KHQR payment and returns the code to scan.
  Future<KhqrPayment> startKhqr(ShippingAddress address);

  Future<bool> verifyKhqr(int orderId);

  /// Gives up on the payment unless it already went through; returns whether it was paid.
  Future<bool> cancelKhqr(int orderId);
}
