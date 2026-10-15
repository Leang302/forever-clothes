import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/paged_result.dart';
import '../../domain/entities/product.dart';
import 'product_dto.dart';

part 'product_page_dto.freezed.dart';
part 'product_page_dto.g.dart';

@freezed
abstract class ProductPageDto with _$ProductPageDto {
  const factory ProductPageDto({
    required List<ProductDto> content,
    required int page,
    required bool last,
    required int totalElements,
  }) = _ProductPageDto;

  factory ProductPageDto.fromJson(Map<String, dynamic> json) =>
      _$ProductPageDtoFromJson(json);
}

extension ProductPageDtoMapper on ProductPageDto {
  PagedResult<Product> toEntity() => PagedResult(
    items: content.map((e) => e.toEntity()).toList(),
    page: page,
    isLast: last,
    total: totalElements,
  );
}
