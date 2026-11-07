import 'package:freezed_annotation/freezed_annotation.dart';

import 'stock.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const Product._();

  const factory Product({
    required int id,
    required String name,
    required String description,
    required double price,
    required String category,
    required String subCategory,
    required List<String> sizes,
    required List<String> images,
    required bool bestseller,

    /// Units left per size (same keys as [sizes]). Empty when the API did not
    /// report stock, in which case availability is left to the server.
    @Default(<String, int>{}) Map<String, int> stock,

    /// Active AND at least one size has stock (computed by the API).
    @Default(true) bool inStock,
  }) = _Product;

  String? get cover => images.isEmpty ? null : images.first;

  /// Units left for [size]. Unknown stock (no map from the API) is treated as
  /// the stepper maximum so the UI does not block what the server may allow.
  int stockOf(String size) {
    if (stock.isEmpty) return inStock ? StockRules.maxPerLine : 0;
    return stock[size] ?? 0;
  }

  bool isSizeAvailable(String size) => inStock && stockOf(size) > 0;

  List<String> get availableSizes =>
      sizes.where(isSizeAvailable).toList(growable: false);

  /// Whether anything at all can be added to the cart.
  bool get canBuy => availableSizes.isNotEmpty;

  /// Dummy data rendered under the skeleton shimmer while real data loads.
  static const placeholder = Product(
    id: 0,
    name: 'Loading product name',
    description: 'Loading product description for the skeleton placeholder.',
    price: 100,
    category: 'Men',
    subCategory: 'Topwear',
    sizes: ['S', 'M', 'L'],
    images: [],
    bestseller: false,
  );
}
