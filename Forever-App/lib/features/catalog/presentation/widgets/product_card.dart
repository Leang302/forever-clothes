import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/network_image.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: product.id == 0
          ? null
          : () => context.push(Routes.productPath(product.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'product-image-${product.id}',
              child: AppNetworkImage(product.cover, radius: 22),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                formatPrice(product.price),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  product.subCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
