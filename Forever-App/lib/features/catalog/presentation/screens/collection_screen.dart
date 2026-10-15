import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/paged_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../providers/catalog_providers.dart';
import '../providers/search_focus_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/product_grid.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _openingFilters = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(productQueryControllerProvider).search;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(productListProvider.notifier).loadMore();
      }
    });
    // The Home search bar asks for focus before this tab may even exist, so also check the current value.
    ref.listenManual<bool>(searchFocusRequestProvider, (_, wanted) {
      if (!wanted) return;
      ref.read(searchFocusRequestProvider.notifier).consume();
      _searchFocus.requestFocus();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // toggles the clear button
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(productQueryControllerProvider.notifier).setSearch(value),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(productQueryControllerProvider.notifier).setSearch('');
  }

  void _clearAllFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(productQueryControllerProvider.notifier).clearSearchAndFilters();
  }

  Future<void> _openFilters() async {
    if (_openingFilters) return;
    setState(() => _openingFilters = true);
    try {
      final options = await ref.read(catalogFiltersProvider.future);
      if (!mounted) return;
      final result = await showFilterSheet(
        context,
        options: options,
        current: ref.read(productQueryControllerProvider),
      );
      if (mounted && result != null) {
        ref
            .read(productQueryControllerProvider.notifier)
            .setFilters(
              categories: result.categories,
              subCategories: result.subCategories,
            );
      }
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(catalogFiltersProvider);
      AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _openingFilters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(productQueryControllerProvider);
    final results = ref.watch(productListProvider);
    final filterOptions = ref.watch(catalogFiltersProvider);
    final updating = results.isLoading && results.hasValue;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: () async => ref.invalidate(productListProvider),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Shop',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 30),
                          ),
                        ),
                        _FilterButton(
                          count: query.activeFilterCount,
                          loading: _openingFilters || filterOptions.isLoading,
                          onPressed: _openFilters,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.muted,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ResultsToolbar(
                      total: results.value?.total,
                      updating: updating,
                      sort: query.sort,
                      onSortChanged: (sort) => ref
                          .read(productQueryControllerProvider.notifier)
                          .setSort(sort),
                    ),
                    if (query.appliedFilterCount > 0) ...[
                      const SizedBox(height: 12),
                      _AppliedFilters(
                        query: query,
                        onRemoveSearch: _clearSearch,
                        onRemoveCategory: (category) => ref
                            .read(productQueryControllerProvider.notifier)
                            .removeCategory(category),
                        onRemoveSubCategory: (subCategory) => ref
                            .read(productQueryControllerProvider.notifier)
                            .removeSubCategory(subCategory),
                        onClearAll: _clearAllFilters,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            ..._resultSlivers(results, query),
            SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultSlivers(
    AsyncValue<PagedResult<Product>> results,
    ProductQuery query,
  ) {
    final padding = const EdgeInsets.symmetric(horizontal: 20);
    if (results.hasError && !results.hasValue) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            error: results.error!,
            onRetry: () => ref.invalidate(productListProvider),
          ),
        ),
      ];
    }
    if (!results.hasValue) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverSkeletonizer(
            enabled: true,
            child: SliverGrid.builder(
              gridDelegate: productGridDelegate,
              itemCount: 6,
              itemBuilder: (_, _) => const ProductCard(Product.placeholder),
            ),
          ),
        ),
      ];
    }
    final page = results.value!;
    final items = page.items;
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            message: 'Try a different search or clear the filters.',
            actionLabel: query.appliedFilterCount == 0 ? null : 'Clear filters',
            onAction: query.appliedFilterCount == 0 ? null : _clearAllFilters,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: padding,
        sliver: SliverGrid.builder(
          gridDelegate: productGridDelegate,
          itemCount: items.length,
          itemBuilder: (_, i) => ProductCard(items[i]),
        ),
      ),
      if (!page.isLast)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _ResultsToolbar extends StatelessWidget {
  const _ResultsToolbar({
    required this.total,
    required this.updating,
    required this.sort,
    required this.onSortChanged,
  });

  final int? total;
  final bool updating;
  final ProductSort sort;
  final ValueChanged<ProductSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final summary = Semantics(
      liveRegion: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            total == null
                ? ' '
                : '$total ${total == 1 ? 'product' : 'products'}',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
          if (updating)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondaryText,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  'Updating…',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    final sortMenu = _SortMenu(value: sort, onChanged: onSortChanged);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
        if (largeText || constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: sortMenu),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: summary),
            const SizedBox(width: 12),
            sortMenu,
          ],
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.loading,
    required this.onPressed,
  });

  final int count;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const ValueKey('open-filters'),
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
      ),
      child: Semantics(
        label: count == 0 ? 'Filters' : 'Filters, $count active',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.tune_rounded, size: 19),
            const SizedBox(width: 7),
            const Text('Filters'),
            if (count > 0) ...[
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppliedFilters extends StatelessWidget {
  const _AppliedFilters({
    required this.query,
    required this.onRemoveSearch,
    required this.onRemoveCategory,
    required this.onRemoveSubCategory,
    required this.onClearAll,
  });

  final ProductQuery query;
  final VoidCallback onRemoveSearch;
  final ValueChanged<String> onRemoveCategory;
  final ValueChanged<String> onRemoveSubCategory;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final search = query.search.trim();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (search.isNotEmpty)
          _RemovableFilterChip(
            chipKey: 'search',
            label: '"$search"',
            onRemove: onRemoveSearch,
          ),
        for (final category in query.categories)
          _RemovableFilterChip(
            chipKey: 'category-$category',
            label: category,
            onRemove: () => onRemoveCategory(category),
          ),
        for (final subCategory in query.subCategories)
          _RemovableFilterChip(
            chipKey: 'sub-category-$subCategory',
            label: subCategory,
            onRemove: () => onRemoveSubCategory(subCategory),
          ),
        if (query.appliedFilterCount > 1)
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Clear all',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
          ),
      ],
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({
    required this.chipKey,
    required this.label,
    required this.onRemove,
  });

  final String chipKey;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      key: ValueKey('active-filter-$chipKey'),
      label: Text(label),
      onPressed: onRemove,
      onDeleted: onRemove,
      deleteButtonTooltipMessage: 'Remove filter $label',
      deleteIcon: const Icon(Icons.close_rounded, size: 17),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final ProductSort value;
  final ValueChanged<ProductSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      tooltip: 'Sort products',
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.surface,
      itemBuilder: (_) => [
        for (final s in ProductSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded, size: 18),
            const SizedBox(width: 5),
            Text(
              value.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
