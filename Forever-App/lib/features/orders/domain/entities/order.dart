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

@freezed
abstract class Order with _$Order {
  const factory Order({
    required int id,
    required OrderStatus status,
    required PaymentMethod paymentMethod,
    required bool paid,
    required double itemsAmount,
    required double deliveryFee,
    required double total,
    required ShippingAddress address,
    required List<OrderItem> items,
    required DateTime createdAt,
  }) = _Order;
}
