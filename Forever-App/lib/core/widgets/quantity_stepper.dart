import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Compact − n + stepper used on product detail, quick-add and the cart.
///
/// [max] is the largest selectable value (e.g. units left in stock); "+" is
/// disabled at it. With [removeAtMin], "−" at 1 shows a bin icon and reports 0
/// (the cart uses this to delete a line).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.max = 99,
    this.removeAtMin = false,
    this.enabled = true,
    this.keyPrefix = 'qty',
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;
  final bool removeAtMin;
  final bool enabled;

  /// Prefix for the `-dec`, `-inc` and `-value` keys (used by tests).
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    Widget button(
      Key key,
      IconData icon,
      String tooltip,
      VoidCallback? onTap,
    ) => Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: GestureDetector(
        key: key,
        // A disabled button still swallows the tap, so it never falls
        // through to a tappable parent (e.g. the cart line opening the
        // product page when "+" is at the stock limit).
        onTap: onTap ?? () {},
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
      ),
    );
    final canDecrease = enabled && (removeAtMin ? quantity > 0 : quantity > 1);
    final canIncrease = enabled && quantity < max;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Key('$keyPrefix-dec'),
            removeAtMin && quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            removeAtMin && quantity <= 1 ? 'Remove' : 'Decrease quantity',
            canDecrease ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 26,
            child: Center(
              child: Text(
                '$quantity',
                key: Key('$keyPrefix-value'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          button(
            Key('$keyPrefix-inc'),
            Icons.add_rounded,
            'Increase quantity',
            canIncrease ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}
