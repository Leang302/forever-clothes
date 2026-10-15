import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/product_query.dart';

typedef FilterSelection = ({
  List<String> categories,
  List<String> subCategories,
});

/// Opens a mobile-native version of the storefront's category filters.
///
/// Changes remain local to the sheet until the customer applies them. A
/// dismissal therefore leaves the current product query untouched.
Future<FilterSelection?> showFilterSheet(
  BuildContext context, {
  required CatalogFilters options,
  required ProductQuery current,
}) {
  return showModalBottomSheet<FilterSelection>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _FilterSheet(options: options, current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.options, required this.current});

  final CatalogFilters options;
  final ProductQuery current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _categories = widget.current.categories
      .where(widget.options.categories.contains)
      .toSet();
  late final Set<String> _subCategories = widget.current.subCategories
      .where(widget.options.subCategories.contains)
      .toSet();

  int get _selectedCount => _categories.length + _subCategories.length;

  void _toggle(Set<String> selected, String value) {
    setState(() {
      if (!selected.add(value)) selected.remove(value);
    });
  }

  void _clear() {
    if (_selectedCount == 0) return;
    setState(() {
      _categories.clear();
      _subCategories.clear();
    });
  }

  void _apply() {
    Navigator.pop(context, (
      categories: widget.options.categories
          .where(_categories.contains)
          .toList(),
      subCategories: widget.options.subCategories
          .where(_subCategories.contains)
          .toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCount;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final heightFactor = viewportHeight < 500 ? 0.96 : 0.86;
    return SizedBox(
      height: viewportHeight * heightFactor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 2, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selected == 0
                            ? 'No filters selected'
                            : '$selected ${selected == 1 ? 'filter' : 'filters'} selected',
                        key: const ValueKey('filter-selection-count'),
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                children: [
                  _FilterSection(
                    title: 'Categories',
                    emptyLabel: 'No categories available',
                    keyPrefix: 'category',
                    values: widget.options.categories,
                    selected: _categories,
                    onToggle: (value) => _toggle(_categories, value),
                  ),
                  const SizedBox(height: 18),
                  _FilterSection(
                    title: 'Sub category',
                    emptyLabel: 'No sub-categories available',
                    keyPrefix: 'sub-category',
                    values: widget.options.subCategories,
                    selected: _subCategories,
                    onToggle: (value) => _toggle(_subCategories, value),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: _FilterActions(
                  selectedCount: selected,
                  onClear: _clear,
                  onApply: _apply,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterActions extends StatelessWidget {
  const _FilterActions({
    required this.selectedCount,
    required this.onClear,
    required this.onApply,
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final clear = OutlinedButton(
      onPressed: selectedCount == 0 ? null : onClear,
      child: const Text('Clear'),
    );
    final apply = AppButton(
      label: selectedCount == 0 ? 'Apply' : 'Apply ($selectedCount)',
      onPressed: onApply,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
        final stackActions = largeText && constraints.maxWidth < 380;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [apply, const SizedBox(height: 8), clear],
          );
        }
        return Row(
          children: [
            Expanded(child: clear),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: apply),
          ],
        );
      },
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.emptyLabel,
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String emptyLabel;
  final String keyPrefix;
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 13),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(),
          if (values.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                emptyLabel,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            )
          else
            for (var index = 0; index < values.length; index++) ...[
              CheckboxListTile(
                key: ValueKey('$keyPrefix-${values[index]}'),
                value: selected.contains(values[index]),
                onChanged: (_) => onToggle(values[index]),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.ink,
                checkColor: Colors.white,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                title: Text(
                  values[index],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (index != values.length - 1)
                const Divider(indent: 54, endIndent: 16),
            ],
        ],
      ),
    );
  }
}
