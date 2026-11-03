import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/order.dart';

part 'checkout_options_dto.freezed.dart';
part 'checkout_options_dto.g.dart';

@freezed
abstract class ShippingOptionDto with _$ShippingOptionDto {
  const factory ShippingOptionDto({
    required String code,
    required String name,
    @JsonKey(fromJson: doubleFromJson) required double fee,
    required String estimate,
  }) = _ShippingOptionDto;

  factory ShippingOptionDto.fromJson(Map<String, dynamic> json) =>
      _$ShippingOptionDtoFromJson(json);
}

extension ShippingOptionDtoMapper on ShippingOptionDto {
  ShippingOption toEntity() =>
      ShippingOption(code: code, name: name, fee: fee, estimate: estimate);
}

@freezed
abstract class CheckoutOptionsDto with _$CheckoutOptionsDto {
  const factory CheckoutOptionsDto({
    required List<ShippingOptionDto> shippingMethods,
  }) = _CheckoutOptionsDto;

  factory CheckoutOptionsDto.fromJson(Map<String, dynamic> json) =>
      _$CheckoutOptionsDtoFromJson(json);
}

@freezed
abstract class CouponPreviewDto with _$CouponPreviewDto {
  const factory CouponPreviewDto({
    required String code,
    String? description,
    required String discountType,
    @JsonKey(fromJson: doubleFromJson) required double discount,
    required String summary,
  }) = _CouponPreviewDto;

  factory CouponPreviewDto.fromJson(Map<String, dynamic> json) =>
      _$CouponPreviewDtoFromJson(json);
}

extension CouponPreviewDtoMapper on CouponPreviewDto {
  CouponPreview toEntity() => CouponPreview(
    code: code,
    description: description,
    discountType: discountType,
    discount: discount,
    summary: summary,
  );
}
