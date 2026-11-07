import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/network_image.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../cart/presentation/add_to_cart.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock.dart';
import '../providers/catalog_providers.dart';
import 'stock_widgets.dart';

/// Bottom sheet for adding a product to the cart straight from a product card:
/// pick an in-stock size and a quantity, then add. Returns whether it added.
Future<bool> showQuickAddSheet(BuildContext context, Product product) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Above the shell's floating nav bar, which would otherwise cover the
      // quantity stepper and the add button.
      useRootNavigator: true,
      builder: (_) => QuickAddSheet(product: product),
    ) ??
    false;

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, required this.product});

  /// The card's copy of the product, shown until the fresh one loads.
  final Product product;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  String? _size;
  int _quantity = 1;
  bool _busy = false;

  /// The picked size if still buyable; with exactly one buyable size there
  /// is nothing to choose, so that one.
  String? _effectiveSize(Product p) {
    if (_size != null && p.isSizeAvailable(_size!)) return _size;
    return p.availableSizes.length == 1 ? p.availableSizes.single : null;
  }

  Future<void> _add(Product product, String size, int quantity) async {
    setState(() => _busy = true);
    final added = await addToCartWithFeedback(
      context,
      ref,
      product: product,
      size: size,
      quantity: quantity,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (added) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch so the size/quantity limits reflect current stock, not the
    // possibly stale list the card came from.
    final fresh = ref.watch(productDetailProvider(widget.product.id)).value;
    final product = fresh ?? widget.product;
    final size = _effectiveSize(product);
    final max = size == null
        ? 1
        : StockRules.maxQuantity(product.stockOf(size));
    final quantity = size == null
        ? _quantity
        : StockRules.clampQuantity(_quantity, product.stockOf(size));
    final canAdd = !_busy && size != null && max > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('quick-add-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 76,
                child: AppNetworkImage(product.cover, radius: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(product.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Size', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              StockStatus(product: product, size: size),
            ],
          ),
          const SizedBox(height: 12),
          SizeSelector(
            product: product,
            selected: size,
            keyPrefix: 'quick-size',
            onSelected: (s) => setState(() {
              _size = s;
              _quantity = StockRules.clampQuantity(
                _quantity,
                product.stockOf(s),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Quantity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              QuantityStepper(
                keyPrefix: 'quick-qty',
                quantity: quantity,
                max: max,
                enabled: size != null,
                onChanged: (q) => setState(() => _quantity = q),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            label: !product.canBuy
                ? 'Out of stock'
                : size == null
                ? 'Select a size'
                : 'Add to cart · ${formatPrice(product.price * quantity)}',
            icon: Icons.shopping_bag_outlined,
            loading: _busy,
            onPressed: canAdd ? () => _add(product, size, quantity) : null,
          ),
        ],
      ),
    );
  }
}
