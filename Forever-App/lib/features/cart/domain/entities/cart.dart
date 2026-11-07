import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../catalog/domain/entities/stock.dart';

part 'cart.freezed.dart';

@freezed
abstract class CartLine with _$CartLine {
  const CartLine._();

  const factory CartLine({
    required int id,
    required int productId,
    required String name,
    required double price,
    String? image,
    required String size,
    required int quantity,

    /// Units left for [size]; null when unknown.
    int? stock,
  }) = _CartLine;

  /// Stepper maximum for this line.
  int get maxQuantity =>
      stock == null ? StockRules.maxPerLine : StockRules.maxQuantity(stock!);

  /// The shopper holds more than is left (stock dropped after they added it).
  bool get exceedsStock => stock != null && quantity > stock!;

  bool get soldOut => stock != null && stock! <= 0;
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

  /// Lines that cannot be ordered as they are (quantity above what's left).
  List<CartLine> get problemLines =>
      items.where((l) => l.exceedsStock).toList(growable: false);

  bool get hasStockProblems => items.any((l) => l.exceedsStock);
}
