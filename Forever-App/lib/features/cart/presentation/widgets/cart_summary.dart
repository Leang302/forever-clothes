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
    this.discount = 0,
    this.couponCode,
    this.shippingLabel,
    this.deliveryFeeOverride,
  });

  final Cart cart;
  final Widget? action;
  final EdgeInsetsGeometry margin;
  final bool shadow;

  /// The applied coupon's saving, if any (checkout only).
  final double discount;
  final String? couponCode;

  /// The chosen shipping method's name, shown next to "Shipping" (checkout only).
  final String? shippingLabel;

  /// Overrides `cart.deliveryFee` with the chosen shipping method's fee (checkout only).
  final double? deliveryFeeOverride;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Flexible + ellipsis: long labels ("Shipping · Express delivery",
          // "Discount (LONGCOUPON)") or large accessibility text must not
          // push the amount off-screen.
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bold ? AppColors.ink : AppColors.muted,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: bold ? 18 : 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
    final deliveryFee = deliveryFeeOverride ?? cart.deliveryFee;
    final saving = discount > cart.subtotal ? cart.subtotal : discount;
    final total = cart.subtotal - saving + deliveryFee;
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
          if (saving > 0)
            row(
              couponCode == null ? 'Discount' : 'Discount ($couponCode)',
              '-${formatMoney(saving)}',
            ),
          row(
            shippingLabel == null ? 'Shipping' : 'Shipping · $shippingLabel',
            formatMoney(deliveryFee),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(),
          ),
          row('Total', formatMoney(total), bold: true),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
