import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../wishlist/presentation/widgets/wishlist_heart_button.dart';
import '../../domain/entities/product.dart';
import 'quick_add_sheet.dart';
import 'stock_widgets.dart';

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
    final real = product.id != 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !real
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
                !real
                    ? AppNetworkImage(product.cover, radius: 22)
                    : Hero(
                        tag: _heroTag,
                        child: AppNetworkImage(product.cover, radius: 22),
                      ),
                if (real)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(product: product, size: 34),
                  ),
                if (real && !product.inStock)
                  const Positioned(left: 8, top: 10, child: OutOfStockBadge()),
                if (real && product.canBuy)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _QuickAddButton(product: product),
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

/// Round "+ bag" button on the card image that opens the quick-add sheet.
/// Its own InkWell wins the tap, so the card's tap-to-detail is unaffected.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      shape: const CircleBorder(),
      child: InkWell(
        key: Key('quick-add-${product.id}'),
        customBorder: const CircleBorder(),
        onTap: () {
          Haptics.tap();
          showQuickAddSheet(context, product);
        },
        child: Tooltip(
          message: 'Quick add ${product.name} to cart',
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.add_shopping_cart_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
