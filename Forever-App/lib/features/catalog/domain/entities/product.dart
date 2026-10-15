import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _Product;

  String? get cover => images.isEmpty ? null : images.first;

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
