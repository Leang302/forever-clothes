import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_query.freezed.dart';

enum ProductSort {
  relevant('relevant', 'Relevant'),
  priceAsc('price_asc', 'Low to high'),
  priceDesc('price_desc', 'High to low'),
  newest('newest', 'Newest');

  const ProductSort(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

@freezed
abstract class ProductQuery with _$ProductQuery {
  const ProductQuery._();

  const factory ProductQuery({
    @Default('') String search,
    @Default(<String>[]) List<String> categories,
    @Default(<String>[]) List<String> subCategories,
    @Default(ProductSort.relevant) ProductSort sort,
  }) = _ProductQuery;

  int get activeFilterCount => categories.length + subCategories.length;

  /// Search is shown as a removable filter on the collection screen too.
  int get appliedFilterCount =>
      activeFilterCount + (search.trim().isEmpty ? 0 : 1);
}
