import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_filters.freezed.dart';

@freezed
abstract class CatalogFilters with _$CatalogFilters {
  const factory CatalogFilters({
    required List<String> categories,
    required List<String> subCategories,
  }) = _CatalogFilters;
}
