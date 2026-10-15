import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/catalog_filters.dart';

part 'filters_dto.freezed.dart';
part 'filters_dto.g.dart';

@freezed
abstract class FiltersDto with _$FiltersDto {
  const factory FiltersDto({
    required List<String> categories,
    required List<String> subCategories,
  }) = _FiltersDto;

  factory FiltersDto.fromJson(Map<String, dynamic> json) =>
      _$FiltersDtoFromJson(json);
}

extension FiltersDtoMapper on FiltersDto {
  CatalogFilters toEntity() =>
      CatalogFilters(categories: categories, subCategories: subCategories);
}
