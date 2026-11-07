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
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/entities/stock.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_providers.dart';
import '../providers/guest_session_providers.dart';
import '../widgets/cart_summary.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // No guest session is started just for opening this tab: a visitor who
  // never added anything has no cart, so there is nothing to load. The
  // session is created lazily by add-to-cart (see `addToCartWithFeedback`),
  // which keeps us well under the API's per-IP guest-session rate limit.

  /// Whether there is a cart to show: the account's, or the guest session's.
  bool get _hasCart =>
      ref.read(currentUserProvider) != null ||
      ref.read(guestSessionProvider) != null;

  @override
  void initState() {
    super.initState();
    // Re-read the cart on open so each line's stock is current and lines
    // that went over stock are flagged before the shopper heads to checkout.
    if (_hasCart) {
      Future.microtask(() {
        if (mounted) ref.invalidate(cartControllerProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider);
    final guestSession = ref.watch(guestSessionProvider);
    final cart = ref.watch(cartControllerProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final anonymousWithoutCart = user == null && guestSession == null;

    Widget body;
    if (anonymousWithoutCart && !auth.isLoading) {
      body = EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Your cart is empty',
        message: 'Browse the collection and add something you love.',
        actionLabel: 'Start shopping',
        onAction: () => context.go(Routes.collection),
      );
    } else if (anonymousWithoutCart) {
      body = Skeletonizer(
        enabled: true,
        child: _CartList(cart: _skeletonCart, bottomInset: bottom),
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

  /// Lines above their stock can't be ordered: explain before checkout and
  /// offer to trim them to what's left (removing sold-out lines).
  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final problems = cart.problemLines;
    if (problems.isEmpty) {
      context.push(Routes.checkout);
      return;
    }
    Haptics.error();
    final fix = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Some items are low on stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock changed since you added these. Adjust them before '
              'checking out:',
            ),
            const SizedBox(height: 10),
            for (final l in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${_problemText(l)}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('fix-stock'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update cart'),
          ),
        ],
      ),
    );
    if (fix != true) return;
    final controller = ref.read(cartControllerProvider.notifier);
    try {
      for (final l in problems) {
        if (l.soldOut) {
          await controller.remove(l);
        } else {
          await controller.setQuantity(l, l.maxQuantity);
        }
      }
      if (context.mounted) AppSnackbar.info(context, 'Cart updated to stock');
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problems = cart.problemLines.length;
    return Column(
      children: [
        if (problems > 0)
          Container(
            key: const Key('stock-warning'),
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    problems == 1
                        ? '1 item has more than is left in stock.'
                        : '$problems items have more than is left in stock.',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
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
            onPressed: () => _checkout(context, ref),
          ),
        ),
      ],
    );
  }
}

String _problemText(CartLine l) => l.soldOut
    ? '${l.name} (size ${l.size}) is sold out'
    : 'Only ${l.stock} left of ${l.name} in size ${l.size} '
          '(you have ${l.quantity})';

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
        key: Key('cart-line-${line.productId}-${line.size}'),
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
                  if (line.exceedsStock) ...[
                    const SizedBox(height: 4),
                    Text(
                      line.soldOut
                          ? 'Sold out — remove to check out'
                          : 'Only ${line.stock} left — reduce quantity',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (line.stock != null &&
                      line.stock! <= StockRules.lowStockThreshold) ...[
                    const SizedBox(height: 4),
                    Text(
                      StockRules.label(line.stock!),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatPrice(line.price * line.quantity),
                          key: Key('line-subtotal-${line.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      QuantityStepper(
                        keyPrefix: 'line-${line.id}',
                        quantity: line.quantity,
                        // Allow stepping down from an over-stock quantity,
                        // never up past what's left.
                        max: line.maxQuantity,
                        removeAtMin: true,
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
