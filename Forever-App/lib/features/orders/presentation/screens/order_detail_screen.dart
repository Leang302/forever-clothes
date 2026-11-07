import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/payment_state_pill.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.guest = false,
  });

  final int orderId;

  /// A guest (no-account) order, readable only with the access token held in
  /// memory for this app run.
  final bool guest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasGuestAccess = ref.watch(
      guestOrderAccessProvider.select((m) => m.containsKey(orderId)),
    );
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
                        : context.go(guest ? Routes.home : Routes.orders),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Order #$orderId',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: (guest && !hasGuestAccess)
                  ? EmptyState(
                      key: const Key('guest-order-unavailable'),
                      icon: Icons.mark_email_read_outlined,
                      title: 'Check your email',
                      message:
                          'Your order confirmation was sent to the email '
                          'address you entered at checkout. For your privacy, '
                          'guest order details are only shown right after '
                          'checkout on this device.',
                      actionLabel: 'Continue shopping',
                      onAction: () => context.go(Routes.home),
                    )
                  : ref
                        .watch(orderDetailProvider(orderId))
                        .when(
                          data: (o) => _Content(order: o),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => ErrorView(
                            error: e,
                            onRetry: () =>
                                ref.invalidate(orderDetailProvider(orderId)),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.order});

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
      ref.invalidate(orderDetailProvider(order.id));
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelled = order.status == OrderStatus.cancelled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          formatDate(order.createdAt),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: cancelled
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.cancelledBy == 'ADMIN'
                          ? 'We cancelled this order.'
                          : 'This order was cancelled.',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (order.cancelReason != null) ...[
                      const SizedBox(height: 8),
                      Text('Reason: ${order.cancelReason}'),
                    ],
                  ],
                )
              : OrderProgress(status: order.status),
        ),
        const SizedBox(height: 16),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 76,
                    child: AppNetworkImage(item.image, radius: 14),
                  ),
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 4),
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
                    formatMoney(item.price * item.quantity),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery address',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text('${order.address.firstName} ${order.address.lastName}'),
              Text(order.address.street),
              Text(
                '${order.address.city}, ${order.address.state} ${order.address.zipcode}',
              ),
              Text(order.address.country),
              const SizedBox(height: 6),
              Text(
                order.address.phone,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _row('Items', formatMoney(order.itemsAmount)),
              if (order.discount > 0)
                _row(
                  order.couponCode == null
                      ? 'Discount'
                      : 'Discount (${order.couponCode})',
                  '-${formatMoney(order.discount)}',
                  color: AppColors.success,
                ),
              _row(
                order.shippingMethod == 'EXPRESS'
                    ? 'Express delivery'
                    : 'Standard delivery',
                formatMoney(order.deliveryFee),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              _row('Total', formatMoney(order.total), bold: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment: ${order.paymentMethod.label}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  PaymentStatePill(order),
                ],
              ),
              if (order.paymentState == PaymentState.awaitingPayment) ...[
                const SizedBox(height: 8),
                const Text(
                  'We have not received this KHQR payment yet.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
              if (order.paymentState == PaymentState.payOnDelivery) ...[
                const SizedBox(height: 8),
                const Text(
                  'Pay in cash when your order is delivered.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (order.status.isCancellable) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Cancel order'),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? (bold ? AppColors.ink : AppColors.muted),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
