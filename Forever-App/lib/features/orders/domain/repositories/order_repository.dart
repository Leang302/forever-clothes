import '../entities/khqr_payment.dart';
import '../entities/order.dart';

abstract interface class OrderRepository {
  /// Creates an order from the server-side cart (which the server then empties).
  ///
  /// [cartItemIds] limits the order to those cart lines; null/empty means the whole cart.
  Future<Order> place({
    required ShippingAddress address,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  });

  Future<List<Order>> list();

  Future<Order> getById(int id);

  Future<Order> cancel(int id);

  /// Creates an order awaiting KHQR payment and returns the code to scan.
  Future<KhqrPayment> startKhqr(
    ShippingAddress address, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  });

  Future<bool> verifyKhqr(int orderId);

  /// Gives up on the payment unless it already went through; returns whether it was paid.
  Future<bool> cancelKhqr(int orderId);

  /// Shipping methods offered at checkout.
  Future<List<ShippingOption>> checkoutOptions();

  /// Previews a coupon's discount for [subtotal]; throws if the code is invalid or doesn't apply.
  Future<CouponPreview> checkCoupon(String code, double subtotal);
}
