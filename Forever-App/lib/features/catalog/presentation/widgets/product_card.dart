import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../wishlist/presentation/widgets/wishlist_heart_button.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key, this.heroTagPrefix});

  final Product product;

  /// Distinguishes this card's Hero tag from the same product shown in another
  /// section mounted at the same time (e.g. "Latest" vs "Best sellers" on Home,
  /// or the main collection grid vs a product's "related" carousel). Screens that
  /// pair 1:1 with [ProductDetailScreen] (the main collection grid) leave this
  /// null so the Hero flight animates between them.
  final String? heroTagPrefix;

  String get _heroTag => heroTagPrefix == null
      ? 'product-image-${product.id}'
      : '$heroTagPrefix-product-image-${product.id}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: product.id == 0
          ? null
          : () => context.push(Routes.productPath(product.id), extra: _heroTag),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Skeleton placeholders all share id 0, so skip the Hero: with several
                // shown at once (e.g. the loading grid) a shared tag would collide.
                product.id == 0
                    ? AppNetworkImage(product.cover, radius: 22)
                    : Hero(
                        tag: _heroTag,
                        child: AppNetworkImage(product.cover, radius: 22),
                      ),
                if (product.id != 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(product: product, size: 34),
                  ),
              ],
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
