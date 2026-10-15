import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/cart.dart';

part 'cart_dto.freezed.dart';
part 'cart_dto.g.dart';

@freezed
abstract class CartLineDto with _$CartLineDto {
  const factory CartLineDto({
    required int id,
    required int productId,
    required String name,
    @JsonKey(fromJson: doubleFromJson) required double price,
    String? image,
    required String size,
    required int quantity,
  }) = _CartLineDto;

  factory CartLineDto.fromJson(Map<String, dynamic> json) =>
      _$CartLineDtoFromJson(json);
}

@freezed
abstract class CartDto with _$CartDto {
  const factory CartDto({
    required List<CartLineDto> items,
    required int itemCount,
    @JsonKey(fromJson: doubleFromJson) required double subtotal,
    @JsonKey(fromJson: doubleFromJson) required double deliveryFee,
    @JsonKey(fromJson: doubleFromJson) required double total,
  }) = _CartDto;

  factory CartDto.fromJson(Map<String, dynamic> json) =>
      _$CartDtoFromJson(json);
}

extension CartDtoMapper on CartDto {
  Cart toEntity() => Cart(
    items: items
        .map(
          (l) => CartLine(
            id: l.id,
            productId: l.productId,
            name: l.name,
            price: l.price,
            image: l.image,
            size: l.size,
            quantity: l.quantity,
          ),
        )
        .toList(),
    itemCount: itemCount,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    total: total,
  );
}
