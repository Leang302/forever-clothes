import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/cart.dart';

/// Subtotal / shipping / total card with a trailing action (checkout or place-order button).
class CartSummary extends StatelessWidget {
  const CartSummary({
    super.key,
    required this.cart,
    this.action,
    this.margin = EdgeInsets.zero,
    this.shadow = true,
  });

  final Cart cart;
  final Widget? action;
  final EdgeInsetsGeometry margin;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontSize: bold ? 18 : 15,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 20 : 15,
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('Subtotal', formatMoney(cart.subtotal)),
          row('Shipping', formatMoney(cart.deliveryFee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(),
          ),
          row('Total', formatMoney(cart.total), bold: true),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
