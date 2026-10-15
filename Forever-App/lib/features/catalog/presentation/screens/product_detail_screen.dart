import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/choice_chip_pill.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../domain/entities/product.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _size;
  bool _adding = false;

  Future<void> _addToCart(Product product) async {
    if (_size == null) {
      Haptics.error();
      AppSnackbar.error(
        context,
        const AppException('Please select a size first'),
      );
      return;
    }
    if (ref.read(currentUserProvider) == null) {
      AppSnackbar.info(context, 'Log in to add items to your cart');
      context.push(Routes.loginWithRedirect(Routes.productPath(product.id)));
      return;
    }
    setState(() => _adding = true);
    try {
      await ref.read(cartControllerProvider.notifier).add(product.id, _size!);
      Haptics.success();
      if (mounted) AppSnackbar.info(context, 'Added to cart');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(widget.productId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: product.when(
        data: (p) => _Content(
          product: p,
          size: _size,
          onSize: (s) => setState(() => _size = s),
        ),
        loading: () => Skeletonizer(
          enabled: true,
          child: _Content(
            product: Product.placeholder,
            size: null,
            onSize: (_) {},
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
        data: (p) => _ActionBar(
          price: p.price,
          busy: _adding,
          onAdd: () => _addToCart(p),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
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
  });

  final Product product;
  final String? size;
  final ValueChanged<String> onSize;

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
            _Gallery(product: product, height: height),
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
                    Text(
                      'Size',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final s in product.sizes)
                          PillChip(
                            label: s,
                            minWidth: 56,
                            selected: s == size,
                            onTap: () => onSize(s),
                          ),
                      ],
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
                                        child: ProductCard(items[i]),
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
        _TopBar(),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product, required this.height});

  final Product product;
  final double height;

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
                      tag: 'product-image-${widget.product.id}',
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
    required this.busy,
    required this.onAdd,
  });

  final double price;
  final bool busy;
  final VoidCallback onAdd;

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
          child: Row(
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
                    formatPrice(price),
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
                  label: 'Add to cart',
                  icon: Icons.shopping_bag_outlined,
                  loading: busy,
                  onPressed: onAdd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
