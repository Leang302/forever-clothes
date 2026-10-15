import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../catalog/domain/entities/product.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../catalog/presentation/providers/search_focus_provider.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../catalog/presentation/widgets/product_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestProductsProvider);
    final best = ref.watch(bestSellersProvider);
    final user = ref.watch(currentUserProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    Future<void> refresh() async {
      ref.invalidate(latestProductsProvider);
      ref.invalidate(bestSellersProvider);
      await ref
          .read(latestProductsProvider.future)
          .catchError((_) => <Product>[]);
    }

    void openCategory(String? category) {
      ref
          .read(productQueryControllerProvider.notifier)
          .selectCategory(category);
      context.go(Routes.collection);
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null ? 'Welcome to' : 'Hello,',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        user == null ? 'Forever' : user.name.split(' ').first,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                      ),
                    ],
                  ),
                ),
                Image.asset('assets/images/logo.png', width: 96),
              ],
            ),
            const SizedBox(height: 18),
            _SearchBar(
              onTap: () {
                ref.read(searchFocusRequestProvider.notifier).request();
                context.go(Routes.collection);
              },
            ),
            const SizedBox(height: 18),
            _HeroBanner(onShop: () => openCategory(null)),
            const SizedBox(height: 22),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  _CategoryChip(
                    icon: Icons.apps_rounded,
                    label: 'All',
                    onTap: () => openCategory(null),
                  ),
                  for (final c in const ['Men', 'Women', 'Kids']) ...[
                    const SizedBox(width: 10),
                    _CategoryChip(
                      icon: _categoryIcon(c),
                      label: c,
                      onTap: () => openCategory(c),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            SectionHeader(
              'Latest collection',
              actionLabel: 'See all',
              onAction: () => openCategory(null),
            ),
            const SizedBox(height: 14),
            latest.when(
              data: (items) => _Carousel(items),
              loading: () => Skeletonizer(
                enabled: true,
                child: _Carousel(List.filled(4, Product.placeholder)),
              ),
              error: (e, _) => SizedBox(
                height: 220,
                child: ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(latestProductsProvider),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader('Best sellers'),
            const SizedBox(height: 14),
            best.when(
              data: (items) => ProductGrid(items),
              loading: () => Skeletonizer(
                enabled: true,
                child: ProductGrid(List.filled(4, Product.placeholder)),
              ),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),
            const _Policies(),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String c) => switch (c) {
    'Men' => Icons.man_rounded,
    'Women' => Icons.woman_rounded,
    _ => Icons.child_care_rounded,
  };
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.muted),
            SizedBox(width: 10),
            Text(
              'Search products',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onShop});

  final VoidCallback onShop;

  static const _pink = Color(0xFFFFDAD6); // same as the hero photo's backdrop

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: AspectRatio(
        aspectRatio: 1.25,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _pink),
            Image.asset(
              'assets/images/hero_img.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_pink, _pink, Color(0x00FFDAD6)],
                  stops: [0, 0.3, 0.62],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Our best seller',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Latest\nArrivals',
                    style: AppTheme.display(size: 34, color: AppColors.ink),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onShop,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text('Shop now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel(this.products);

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) =>
            SizedBox(width: 168, child: ProductCard(products[i])),
      ),
    );
  }
}

class _Policies extends StatelessWidget {
  const _Policies();

  @override
  Widget build(BuildContext context) {
    Widget item(String asset, String title, String subtitle) => Expanded(
      child: Column(
        children: [
          Image.asset('assets/images/$asset.png', width: 40, height: 40),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item('exchange_icon', 'Easy exchange', 'Free exchange policy'),
          item('quality_icon', '7-day returns', 'Free return window'),
          item('support_img', '24/7 support', 'We are here to help'),
        ],
      ),
    );
  }
}
