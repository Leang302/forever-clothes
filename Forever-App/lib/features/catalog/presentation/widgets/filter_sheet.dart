import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/choice_chip_pill.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/product_query.dart';

typedef FilterSelection = ({
  List<String> categories,
  List<String> subCategories,
});

/// Bottom sheet with multi-select category / type chips. Resolves to the new selection, or null if dismissed.
Future<FilterSelection?> showFilterSheet(
  BuildContext context, {
  required CatalogFilters options,
  required ProductQuery current,
}) {
  return showModalBottomSheet<FilterSelection>(
    context: context,
    isScrollControlled: true,
    useRootNavigator:
        true, // the floating nav bar lives above the tab navigators
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
  late final Set<String> _categories = {...widget.current.categories};
  late final Set<String> _types = {...widget.current.subCategories};

  Widget _group(String title, List<String> values, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final v in values)
              PillChip(
                label: v,
                selected: selected.contains(v),
                onTap: () => setState(
                  () => selected.contains(v)
                      ? selected.remove(v)
                      : selected.add(v),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            _group('Category', widget.options.categories, _categories),
            const SizedBox(height: 24),
            _group('Type', widget.options.subCategories, _types),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, (
                      categories: <String>[],
                      subCategories: <String>[],
                    )),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Apply',
                    onPressed: () => Navigator.pop(context, (
                      categories: _categories.toList(),
                      subCategories: _types.toList(),
                    )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
