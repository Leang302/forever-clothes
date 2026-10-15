import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/order.dart';
import '../providers/order_providers.dart';
import '../widgets/order_progress.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                    'My orders',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders yet',
                        message:
                            'When you place an order it will show up here.',
                        actionLabel: 'Start shopping',
                        onAction: () => context.go(Routes.collection),
                      )
                    : _OrderList(list),
                loading: () => Skeletonizer(
                  enabled: true,
                  child: _OrderList(List.filled(2, _skeleton)),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(ordersControllerProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _skeleton = Order(
    id: 0,
    status: OrderStatus.orderPlaced,
    paymentMethod: PaymentMethod.cod,
    paid: false,
    itemsAmount: 100,
    deliveryFee: 10,
    total: 110,
    address: const ShippingAddress(
      firstName: 'A',
      lastName: 'B',
      email: 'a@b.c',
      street: 's',
      city: 'c',
      state: 's',
      zipcode: '0',
      country: 'c',
      phone: '0',
    ),
    items: const [
      OrderItem(
        name: 'Loading product name',
        price: 100,
        size: 'M',
        quantity: 1,
      ),
    ],
    createdAt: DateTime(2026),
  );
}

class _OrderList extends ConsumerWidget {
  const _OrderList(this.orders);

  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.read(ordersControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _OrderCard(orders[i]),
      ),
    );
  }
}

Color statusColor(OrderStatus s) => switch (s) {
  OrderStatus.delivered => AppColors.success,
  OrderStatus.cancelled => AppColors.danger,
  OrderStatus.shipped => AppColors.info,
  _ => AppColors.warning,
};

class _OrderCard extends ConsumerWidget {
  const _OrderCard(this.order);

  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel order #${order.id}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(ordersControllerProvider.notifier).cancel(order.id);
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = statusColor(order.status);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      formatDate(order.createdAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _StatusBadge(order.status.label, color),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in order.items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 62,
                    child: AppNetworkImage(item.image, radius: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Size ${item.size} · Qty ${item.quantity}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPrice(item.price),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (order.items.length > 3)
            Text(
              '+ ${order.items.length - 3} more items',
              style: const TextStyle(color: AppColors.muted),
            ),
          if (order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 8),
            OrderProgress(status: order.status),
          ],
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${order.paymentMethod.label}${order.paid ? ' · paid' : ''}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                formatMoney(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (order.status.isCancellable) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancel(context, ref),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Cancel order'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
