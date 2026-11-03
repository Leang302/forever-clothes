import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/presentation/widgets/product_grid.dart';
import '../providers/wishlist_providers.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.profile),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'My wishlist',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Expanded(
              child: wishlist.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Your wishlist is empty',
                        message: 'Tap the heart on a product to save it here.',
                        actionLabel: 'Start shopping',
                        onAction: () => context.go(Routes.collection),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(wishlistControllerProvider.future),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          children: [
                            ProductGrid(list, heroTagPrefix: 'wishlist'),
                          ],
                        ),
                      ),
                loading: () => Skeletonizer(
                  enabled: true,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      ProductGrid(
                        List.filled(4, Product.placeholder),
                        heroTagPrefix: 'wishlist',
                      ),
                    ],
                  ),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(wishlistControllerProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
