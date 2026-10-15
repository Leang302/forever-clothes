import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/choice_chip_pill.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/state_views.dart';
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

  Future<void> _openFilters() async {
    final options = await ref.read(catalogFiltersProvider.future);
    if (!mounted) return;
    final result = await showFilterSheet(
      context,
      options: options,
      current: ref.read(productQueryControllerProvider),
    );
    if (result != null) {
      ref
          .read(productQueryControllerProvider.notifier)
          .setFilters(
            categories: result.categories,
            subCategories: result.subCategories,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(productQueryControllerProvider);
    final results = ref.watch(productListProvider);
    final filters = ref.watch(catalogFiltersProvider).value;
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
                        CircleIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Filters',
                          badgeCount: query.activeFilterCount,
                          onTap: _openFilters,
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
                                onPressed: () {
                                  _search.clear();
                                  _onSearchChanged('');
                                },
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
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: [
                          PillChip(
                            label: 'All',
                            selected: query.categories.isEmpty,
                            onTap: () => ref
                                .read(productQueryControllerProvider.notifier)
                                .selectCategory(null),
                          ),
                          for (final c
                              in filters?.categories ??
                                  const ['Men', 'Women', 'Kids']) ...[
                            const SizedBox(width: 10),
                            PillChip(
                              label: c,
                              selected:
                                  query.categories.length == 1 &&
                                  query.categories.first == c,
                              onTap: () => ref
                                  .read(productQueryControllerProvider.notifier)
                                  .selectCategory(c),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            results.value == null
                                ? ' '
                                : '${results.value!.total} products',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                        _SortMenu(
                          value: query.sort,
                          onChanged: (s) => ref
                              .read(productQueryControllerProvider.notifier)
                              .setSort(s),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            ..._resultSlivers(results),
            SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultSlivers(AsyncValue<dynamic> results) {
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
    final items = page.items as List<Product>;
    if (items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            message: 'Try a different search or clear the filters.',
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

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final ProductSort value;
  final ValueChanged<ProductSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.surface,
      itemBuilder: (_) => [
        for (final s in ProductSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_vert_rounded, size: 18),
          const SizedBox(width: 4),
          Text(
            value.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
