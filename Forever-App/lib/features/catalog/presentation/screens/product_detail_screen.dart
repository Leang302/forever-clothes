import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../cart/presentation/add_to_cart.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../wishlist/presentation/widgets/wishlist_heart_button.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_card.dart';
import '../widgets/stock_widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.heroTag});

  final int productId;

  /// The tag of the card that was tapped to get here, so the gallery's Hero
  /// flight matches it. Null for a cold open (e.g. a deep link); the gallery
  /// then falls back to the plain `product-image-$productId` tag.
  final String? heroTag;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _size;
  int _quantity = 1;
  bool _adding = false;

  /// The picked size, dropped if it sold out since (e.g. after a 409 refresh).
  String? _effectiveSize(Product p) =>
      _size != null && p.isSizeAvailable(_size!) ? _size : null;

  /// Quantity kept within what's left of the selected size.
  int _effectiveQuantity(Product p) {
    final size = _effectiveSize(p);
    return size == null
        ? _quantity
        : StockRules.clampQuantity(_quantity, p.stockOf(size));
  }

  Future<void> _addToCart(Product product) async {
    final size = _effectiveSize(product);
    if (size == null) {
      Haptics.error();
      AppSnackbar.error(
        context,
        const AppException('Please select a size first'),
      );
      return;
    }
    setState(() => _adding = true);
    // Anonymous shoppers get an anonymous guest cart session (created only
    // now, when it is actually needed) and are never sent to the login screen.
    await addToCartWithFeedback(
      context,
      ref,
      product: product,
      size: size,
      quantity: _effectiveQuantity(product),
    );
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(widget.productId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: product.when(
        // Keep showing the product (not a skeleton) while a 409 refresh runs.
        skipLoadingOnRefresh: true,
        data: (p) => _Content(
          product: p,
          size: _effectiveSize(p),
          onSize: (s) => setState(() {
            _size = s;
            _quantity = StockRules.clampQuantity(_quantity, p.stockOf(s));
          }),
          heroTag: widget.heroTag,
        ),
        loading: () => Skeletonizer(
          enabled: true,
          child: _Content(
            product: Product.placeholder,
            size: null,
            onSize: (_) {},
            heroTag: widget.heroTag,
          ),
        ),
        error: (e, _) => Stack(
          children: [
            ErrorView(
              error: e,
              onRetry: () =>
                  ref.invalidate(productDetailProvider(widget.productId)),
            ),
            _TopBar(),
          ],
        ),
      ),
      bottomNavigationBar: product.maybeWhen(
        skipLoadingOnRefresh: true,
        data: (p) {
          final size = _effectiveSize(p);
          return _ActionBar(
            price: p.price,
            quantity: _effectiveQuantity(p),
            maxQuantity: size == null
                ? StockRules.maxPerLine
                : StockRules.maxQuantity(p.stockOf(size)),
            quantityEnabled: size != null,
            onQuantityChanged: (q) => setState(() => _quantity = q),
            busy: _adding,
            label: p.canBuy ? 'Add to cart' : 'Out of stock',
            // Nothing buyable: disabled. Otherwise tapping without a size
            // explains what's missing.
            onAdd: p.canBuy ? () => _addToCart(p) : null,
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({this.product});

  final Product? product;

  /// Shares via the native OS share sheet — on a real device this surfaces
  /// Messages/Mail/Facebook/Telegram/etc. as options, which is the right
  /// mobile pattern (vs. deep-linking a specific social app's API).
  ///
  /// The link points at the React storefront's `/product/:id` page (served
  /// with Open Graph tags for link previews). Its host is
  /// [AppConfig.webBaseUrl]: pass the deployed public URL with
  /// `--dart-define=WEB_BASE_URL=https://…` for real recipients; the dev
  /// default only resolves on this machine/emulator.
  void _shareProduct(BuildContext context, Product product) {
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(
      ShareParams(
        text: productShareText(
          name: product.name,
          price: formatPrice(product.price),
          productId: product.id,
        ),
        // iPad needs an anchor for the share popover.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back',
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(Routes.home),
            ),
            const Spacer(),
            if (product != null && product!.id != 0) ...[
              CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share',
                onTap: () => _shareProduct(context, product!),
              ),
              const SizedBox(width: 10),
              WishlistHeartButton(product: product!, size: 44),
              const SizedBox(width: 10),
            ],
            CircleIconButton(
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Cart',
              badgeCount: ref.watch(cartCountProvider),
              onTap: () => context.go(Routes.cart),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.product,
    required this.size,
    required this.onSize,
    this.heroTag,
  });

  final Product product;
  final String? size;
  final ValueChanged<String> onSize;
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = MediaQuery.sizeOf(context).height * 0.5;
    final related = product.id == 0
        ? null
        : ref.watch(relatedProductsProvider(product.id));
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            _Gallery(product: product, height: height, heroTag: heroTag),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.category} · ${product.subCategory}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatPrice(product.price),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Size',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (product.id != 0)
                          StockStatus(product: product, size: size),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizeSelector(
                      product: product,
                      selected: size,
                      onSelected: onSize,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _Perks(),
                    if (related != null)
                      related.maybeWhen(
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 32),
                                  const SectionHeader('You may also like'),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 250,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      clipBehavior: Clip.none,
                                      itemCount: items.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 14),
                                      itemBuilder: (_, i) => SizedBox(
                                        width: 150,
                                        child: ProductCard(
                                          items[i],
                                          heroTagPrefix: 'related',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        _TopBar(product: product),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product, required this.height, this.heroTag});

  final Product product;
  final double height;
  final String? heroTag;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.isEmpty ? 1 : images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final image = AppNetworkImage(images.isEmpty ? null : images[i]);
              return i == 0
                  ? Hero(
                      tag:
                          widget.heroTag ??
                          'product-image-${widget.product.id}',
                      child: image,
                    )
                  : image;
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.ink
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Perks extends StatelessWidget {
  const _Perks();

  @override
  Widget build(BuildContext context) {
    Widget perk(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.fill,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        perk(Icons.verified_outlined, '100% original'),
        perk(Icons.payments_outlined, 'Cash on delivery'),
        perk(Icons.autorenew_rounded, '7-day exchange'),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.price,
    required this.quantity,
    required this.maxQuantity,
    required this.quantityEnabled,
    required this.onQuantityChanged,
    required this.busy,
    required this.label,
    required this.onAdd,
  });

  final double price;
  final int quantity;
  final int maxQuantity;
  final bool quantityEnabled;
  final ValueChanged<int> onQuantityChanged;
  final bool busy;
  final String label;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  QuantityStepper(
                    quantity: quantity,
                    max: maxQuantity,
                    enabled: quantityEnabled,
                    onChanged: onQuantityChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      Text(
                        formatPrice(price * quantity),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: AppButton(
                      label: label,
                      icon: Icons.shopping_bag_outlined,
                      loading: busy,
                      onPressed: onAdd,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
