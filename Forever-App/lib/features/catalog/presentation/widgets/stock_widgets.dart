import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/choice_chip_pill.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock.dart';

/// Size chips; sold-out sizes are shown but disabled.
class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.product,
    required this.selected,
    required this.onSelected,
    this.keyPrefix = 'size',
  });

  final Product product;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Each chip gets `Key('$keyPrefix-<size>')` (used by tests).
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in product.sizes)
          PillChip(
            key: Key('$keyPrefix-$s'),
            label: s,
            minWidth: 56,
            selected: s == selected,
            enabled: product.isSizeAvailable(s),
            onTap: () => onSelected(s),
          ),
      ],
    );
  }
}

/// "In stock" / "Only N left" / "Out of stock" for the selected size, or the
/// product overall (from `inStock`) before a size is picked.
class StockStatus extends StatelessWidget {
  const StockStatus({super.key, required this.product, this.size});

  final Product product;
  final String? size;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (size == null) {
      label = product.canBuy ? 'In stock' : 'Out of stock';
      color = product.canBuy ? AppColors.success : AppColors.danger;
    } else {
      final left = product.inStock ? product.stockOf(size!) : 0;
      label = StockRules.label(left);
      color = left <= 0
          ? AppColors.danger
          : left <= StockRules.lowStockThreshold
          ? AppColors.warning
          : AppColors.success;
    }
    return Row(
      key: const Key('stock-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Small "Out of stock" label laid over a product image.
class OutOfStockBadge extends StatelessWidget {
  const OutOfStockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Out of stock',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
