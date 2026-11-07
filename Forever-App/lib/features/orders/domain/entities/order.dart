import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

enum OrderStatus {
  orderPlaced('ORDER_PLACED', 'Order placed'),
  shipped('SHIPPED', 'Shipped'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled');

  const OrderStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  bool get isCancellable => this == orderPlaced;

  static OrderStatus fromApi(String value) => values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => OrderStatus.orderPlaced,
  );
}

enum PaymentMethod {
  cod('COD', 'Cash on delivery'),
  khqr('KHQR', 'KHQR'),
  stripe('STRIPE', 'Stripe'),
  razorpay('RAZORPAY', 'Razorpay');

  const PaymentMethod(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String value) => values.firstWhere(
    (m) => m.apiValue == value,
    orElse: () => PaymentMethod.cod,
  );
}

@freezed
abstract class ShippingAddress with _$ShippingAddress {
  const factory ShippingAddress({
    required String firstName,
    required String lastName,
    required String email,
    required String street,
    required String city,
    required String state,
    required String zipcode,
    required String country,
    required String phone,
  }) = _ShippingAddress;
}

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    int? productId,
    required String name,
    String? image,
    required double price,
    required String size,
    required int quantity,
  }) = _OrderItem;
}

/// How an order stands payment-wise, as shown to the shopper.
enum PaymentState {
  paid('Paid'),
  awaitingPayment('Awaiting payment'),
  payOnDelivery('Pay on delivery'),
  notPaid('Not paid');

  const PaymentState(this.label);
  final String label;
}

@freezed
abstract class Order with _$Order {
  const Order._();

  const factory Order({
    required int id,
    required OrderStatus status,
    required PaymentMethod paymentMethod,
    required bool paid,
    required double itemsAmount,
    required double deliveryFee,
    @Default(0) double discount,
    String? couponCode,
    String? shippingMethod,
    required double total,
    required ShippingAddress address,
    required List<OrderItem> items,
    required DateTime createdAt,
    String? cancelReason,
    String? cancelledBy,

    /// Placed without an account (anonymous guest checkout).
    @Default(false) bool guest,
  }) = _Order;

  /// Only the server's `paid` flag (set after Bakong confirms the KHQR
  /// transfer, or by an admin for COD) ever yields [PaymentState.paid].
  PaymentState get paymentState {
    if (paid) return PaymentState.paid;
    if (status == OrderStatus.cancelled) return PaymentState.notPaid;
    return paymentMethod == PaymentMethod.cod
        ? PaymentState.payOnDelivery
        : PaymentState.awaitingPayment;
  }
}

/// A delivery option offered at checkout, fetched from `/api/checkout/options`.
@freezed
abstract class ShippingOption with _$ShippingOption {
  const factory ShippingOption({
    required String code,
    required String name,
    required double fee,
    required String estimate,
  }) = _ShippingOption;
}

/// Result of previewing a coupon code against a subtotal at checkout.
@freezed
abstract class CouponPreview with _$CouponPreview {
  const factory CouponPreview({
    required String code,
    String? description,
    required String discountType,
    required double discount,
    required String summary,
  }) = _CouponPreview;
}

/// The result of placing an order.
///
/// [guestAccessToken] is set only for an anonymous guest checkout: it is what
/// lets this device show the confirmation / finish a KHQR payment through
/// `/api/guest-orders/{id}` (`X-Order-Access`). Hold it in memory only.
class PlacedOrder {
  const PlacedOrder(this.order, {this.guestAccessToken});

  final Order order;
  final String? guestAccessToken;

  @override
  String toString() => 'PlacedOrder(#${order.id})'; // never print the token
}
