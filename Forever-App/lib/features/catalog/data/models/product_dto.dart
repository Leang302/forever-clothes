import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/product.dart';

part 'product_dto.freezed.dart';
part 'product_dto.g.dart';

@freezed
abstract class ProductDto with _$ProductDto {
  const factory ProductDto({
    required int id,
    required String name,
    required String description,
    @JsonKey(fromJson: doubleFromJson) required double price,
    required String category,
    required String subCategory,
    required List<String> sizes,
    required List<String> images,
    @Default(false) bool bestseller,
  }) = _ProductDto;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);
}

extension ProductDtoMapper on ProductDto {
  Product toEntity() => Product(
    id: id,
    name: name,
    description: description,
    price: price,
    category: category,
    subCategory: subCategory,
    sizes: sizes,
    images: images,
    bestseller: bestseller,
  );
}
