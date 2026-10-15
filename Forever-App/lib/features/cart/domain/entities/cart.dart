import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart.freezed.dart';

@freezed
abstract class CartLine with _$CartLine {
  const factory CartLine({
    required int id,
    required int productId,
    required String name,
    required double price,
    String? image,
    required String size,
    required int quantity,
  }) = _CartLine;
}

@freezed
abstract class Cart with _$Cart {
  const Cart._();

  const factory Cart({
    required List<CartLine> items,
    required int itemCount,
    required double subtotal,
    required double deliveryFee,
    required double total,
  }) = _Cart;

  static const empty = Cart(
    items: [],
    itemCount: 0,
    subtotal: 0,
    deliveryFee: 0,
    total: 0,
  );

  bool get isEmpty => items.isEmpty;
}
