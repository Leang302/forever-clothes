import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_providers.dart';
import '../widgets/cart_summary.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cart = ref.watch(cartControllerProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget body;
    if (user == null) {
      body = EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Log in to see your cart',
        message:
            'Your bag is saved to your account so you can pick it up on any device.',
        actionLabel: 'Log in',
        onAction: () => context.push(Routes.loginWithRedirect(Routes.cart)),
      );
    } else if (cart.hasError && !cart.hasValue) {
      body = ErrorView(
        error: cart.error!,
        onRetry: () => ref.invalidate(cartControllerProvider),
      );
    } else if (!cart.hasValue) {
      body = Skeletonizer(
        enabled: true,
        child: _CartList(cart: _skeletonCart, bottomInset: bottom),
      );
    } else if (cart.value!.isEmpty) {
      body = EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Your cart is empty',
        message: 'Browse the collection and add something you love.',
        actionLabel: 'Start shopping',
        onAction: () => context.go(Routes.collection),
      );
    } else {
      body = _CartList(cart: cart.value!, bottomInset: bottom);
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'My cart',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 30),
                ),
                const SizedBox(width: 10),
                if ((cart.value?.itemCount ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${cart.value!.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  static const _skeletonCart = Cart(
    items: [
      CartLine(
        id: 1,
        productId: 1,
        name: 'Loading product name',
        price: 100,
        size: 'M',
        quantity: 1,
      ),
      CartLine(
        id: 2,
        productId: 2,
        name: 'Loading product name',
        price: 100,
        size: 'M',
        quantity: 1,
      ),
    ],
    itemCount: 2,
    subtotal: 200,
    deliveryFee: 10,
    total: 210,
  );
}

class _CartList extends ConsumerWidget {
  const _CartList({required this.cart, required this.bottomInset});

  final Cart cart;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () async => ref.invalidate(cartControllerProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CartTile(cart.items[i]),
            ),
          ),
        ),
        CartSummary(
          cart: cart,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 6),
          action: AppButton(
            label: 'Checkout',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(Routes.checkout),
          ),
        ),
      ],
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile(this.line);

  final CartLine line;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);
    return Dismissible(
      key: ValueKey('line-${line.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        Haptics.light();
        _run(context, () => controller.remove(line));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 26),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push(Routes.productPath(line.productId)),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 104,
              child: AppNetworkImage(line.image, radius: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Size ${line.size}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        formatPrice(line.price * line.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      _Stepper(
                        quantity: line.quantity,
                        onChanged: (q) {
                          Haptics.tap();
                          _run(
                            context,
                            () => q == 0
                                ? controller.remove(line)
                                : controller.setQuantity(line, q),
                          );
                        },
                      ),
                    ],
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

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.line : AppColors.ink,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          button(
            quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 22,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          button(
            Icons.add_rounded,
            quantity >= 99 ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}
