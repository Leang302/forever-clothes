import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/order.dart';

part 'order_dto.freezed.dart';
part 'order_dto.g.dart';

@freezed
abstract class AddressDto with _$AddressDto {
  const factory AddressDto({
    required String firstName,
    required String lastName,
    required String email,
    required String street,
    required String city,
    required String state,
    required String zipcode,
    required String country,
    required String phone,
  }) = _AddressDto;

  factory AddressDto.fromJson(Map<String, dynamic> json) =>
      _$AddressDtoFromJson(json);

  factory AddressDto.fromEntity(ShippingAddress a) => AddressDto(
    firstName: a.firstName,
    lastName: a.lastName,
    email: a.email,
    street: a.street,
    city: a.city,
    state: a.state,
    zipcode: a.zipcode,
    country: a.country,
    phone: a.phone,
  );
}

@freezed
abstract class OrderItemDto with _$OrderItemDto {
  const factory OrderItemDto({
    int? productId,
    required String name,
    String? image,
    @JsonKey(fromJson: doubleFromJson) required double price,
    required String size,
    required int quantity,
  }) = _OrderItemDto;

  factory OrderItemDto.fromJson(Map<String, dynamic> json) =>
      _$OrderItemDtoFromJson(json);
}

@freezed
abstract class OrderDto with _$OrderDto {
  const factory OrderDto({
    required int id,
    required String status,
    required String paymentMethod,
    required bool paid,
    @JsonKey(fromJson: doubleFromJson) required double itemsAmount,
    @JsonKey(fromJson: doubleFromJson) required double deliveryFee,
    @JsonKey(fromJson: doubleFromJson) required double total,
    required AddressDto address,
    required List<OrderItemDto> items,
    required String createdAt,
  }) = _OrderDto;

  factory OrderDto.fromJson(Map<String, dynamic> json) =>
      _$OrderDtoFromJson(json);
}

extension OrderDtoMapper on OrderDto {
  Order toEntity() => Order(
    id: id,
    status: OrderStatus.fromApi(status),
    paymentMethod: PaymentMethod.fromApi(paymentMethod),
    paid: paid,
    itemsAmount: itemsAmount,
    deliveryFee: deliveryFee,
    total: total,
    address: ShippingAddress(
      firstName: address.firstName,
      lastName: address.lastName,
      email: address.email,
      street: address.street,
      city: address.city,
      state: address.state,
      zipcode: address.zipcode,
      country: address.country,
      phone: address.phone,
    ),
    items: items
        .map(
          (i) => OrderItem(
            productId: i.productId,
            name: i.name,
            image: i.image,
            price: i.price,
            size: i.size,
            quantity: i.quantity,
          ),
        )
        .toList(),
    createdAt: DateTime.parse(createdAt).toLocal(),
  );
}
