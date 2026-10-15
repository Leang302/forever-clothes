import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import 'product_card.dart';

const productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 14,
  mainAxisSpacing: 22,
  childAspectRatio: 0.66,
);

/// Non-scrolling 2-column grid for use inside other scroll views.
class ProductGrid extends StatelessWidget {
  const ProductGrid(this.products, {super.key});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: productGridDelegate,
      itemCount: products.length,
      itemBuilder: (_, i) => ProductCard(products[i]),
    );
  }
}
