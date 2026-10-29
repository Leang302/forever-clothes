import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/presentation/profile_sheets.dart';
import 'admin_ui.dart';
import 'coupon_form_screen.dart';
import 'product_form_screen.dart';

const _sections = <String, (String, IconData)>{
  'products': ('Products', Icons.checkroom_outlined),
  'orders': ('Orders', Icons.receipt_long_outlined),
  'inventory': ('Inventory', Icons.inventory_2_outlined),
  'customers': ('Customers', Icons.people_outline),
  'categories': ('Categories', Icons.category_outlined),
  'coupons': ('Coupons', Icons.local_offer_outlined),
  'analytics': ('Analytics', Icons.bar_chart_outlined),
  'notifications': ('Notifications', Icons.notifications_outlined),
};

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({
    super.key,
    this.section,
    this.initialQuery,
    this.initialStatus,
    this.initialActive,
  });

  final String? section;
  final String? initialQuery;
  final String? initialStatus;
  final bool? initialActive;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchController = TextEditingController();
  Object? _data;
  Map<String, dynamic>? _recentOrders;
  Map<String, dynamic>? _analyticsPreview;
  Map<String, dynamic>? _notificationPreview;
  String? _error;
  bool _loading = true;
  bool _filtersExpanded = false;
  int _page = 0;
  String _query = '';
  String? _status;
  bool? _active;
  bool _lowStockOnly = false;
  String _sort = 'newest';
  String? _category;
  String? _subCategory;
  String? _paymentMethod;
  bool? _paid;
  DateTimeRange? _orderDates;
  String? _coupon;
  List<Map<String, dynamic>> _categoryOptions = [];
  List<Map<String, dynamic>> _subCategoryOptions = [];

  String get _section => widget.section ?? 'dashboard';
  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _searchController.text = _query;
    _status = widget.initialStatus;
    _active = widget.initialActive;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.initialActive != widget.initialActive) {
      _page = 0;
      _query = widget.initialQuery ?? '';
      _searchController.text = _query;
      _status = widget.initialStatus;
      _active = widget.initialActive;
      _lowStockOnly = false;
      _sort = 'newest';
      _category = null;
      _subCategory = null;
      _paymentMethod = null;
      _paid = null;
      _orderDates = null;
      _coupon = null;
      _filtersExpanded = false;
      _data = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_section == 'products' && _categoryOptions.isEmpty) {
        final categories = await _dio.get<List<dynamic>>(
          '/api/admin/categories',
        );
        _categoryOptions = (categories.data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (_section == 'dashboard') {
        final statsRequest = _dio.get<Map<String, dynamic>>('/api/admin/stats');
        Future<Map<String, dynamic>?> optional(
          String path, {
          Map<String, dynamic>? query,
        }) => _dio
            .get<Map<String, dynamic>>(path, queryParameters: query)
            .then((response) => response.data)
            .catchError((Object _) => <String, dynamic>{});
        final recentRequest = optional(
          '/api/admin/orders',
          query: {'page': 0, 'size': 5},
        );
        final analyticsRequest = optional('/api/admin/analytics');
        final notificationsRequest = optional(
          '/api/admin/notifications',
          query: {'limit': 1},
        );
        final stats = await statsRequest;
        final recent = await recentRequest;
        final analytics = await analyticsRequest;
        final notifications = await notificationsRequest;
        if (mounted) {
          setState(() {
            _data = stats.data;
            _recentOrders = recent;
            _analyticsPreview = analytics;
            _notificationPreview = notifications;
          });
        }
        return;
      }
      final response = await _dio.get<Object?>(
        '/api/admin/$_section',
        queryParameters: _section == 'products' || _section == 'orders'
            ? {
                'page': _page,
                'size': 20,
                'sort': _sort,
                if (_query.isNotEmpty) 'q': _query,
                if (_section == 'orders' && _status != null) 'status': _status,
                if (_section == 'products' && _active != null)
                  'active': _active,
                if (_section == 'products' && _category != null)
                  'category': _category,
                if (_section == 'products' && _subCategory != null)
                  'subCategory': _subCategory,
                if (_section == 'orders' && _paymentMethod != null)
                  'paymentMethod': _paymentMethod,
                if (_section == 'orders' && _paid != null) 'paid': _paid,
                if (_section == 'orders' && _coupon != null) 'coupon': _coupon,
                if (_section == 'orders' && _orderDates != null)
                  'from':
                      '${_orderDates!.start.year}-${_orderDates!.start.month.toString().padLeft(2, '0')}-${_orderDates!.start.day.toString().padLeft(2, '0')}',
                if (_section == 'orders' && _orderDates != null)
                  'to':
                      '${_orderDates!.end.year}-${_orderDates!.end.month.toString().padLeft(2, '0')}-${_orderDates!.end.day.toString().padLeft(2, '0')}',
              }
            : null,
      );
      if (mounted) setState(() => _data = response.data);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) return '${body['message']}';
    return e.message ?? 'Could not load data';
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<String?> _ask(
    String title, {
    String initial = '',
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openForm(Widget screen) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (saved == true) await _load();
  }

  Future<void> _selectCategory(String? category) async {
    setState(() {
      _category = category;
      _subCategory = null;
      _subCategoryOptions = [];
      _page = 0;
    });
    if (category != null) {
      final selected = _categoryOptions
          .where((item) => item['name'] == category)
          .firstOrNull;
      if (selected != null) {
        try {
          final response = await _dio.get<List<dynamic>>(
            '/api/admin/categories/${selected['id']}/sub-categories',
          );
          if (mounted) {
            setState(
              () => _subCategoryOptions = (response.data ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            );
          }
        } on DioException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_message(e))));
          }
        }
      }
    }
    if (mounted) await _load();
  }

  void _clearFilters() {
    _searchController.clear();
    _query = '';
    _status = null;
    _active = null;
    _sort = 'newest';
    _category = null;
    _subCategory = null;
    _paymentMethod = null;
    _paid = null;
    _orderDates = null;
    _coupon = null;
    _lowStockOnly = false;
    _page = 0;
    if (_section == 'products' || _section == 'orders') {
      _load();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _sections[_section]?.$1 ?? 'Dashboard';
    return Scaffold(
      drawer: _navigationDrawer(),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open admin navigation',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FOREVER  /  ADMIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            tooltip: 'Account and settings',
            onSelected: (value) async {
              if (value == 'server') {
                final address = await showServerAddressDialog(
                  context,
                  ref.read(baseUrlProvider),
                );
                if (address == null) return;
                await ref.read(baseUrlProvider.notifier).change(address);
                await _load();
              } else if (value == 'profile') {
                final user = ref.read(currentUserProvider);
                if (user != null && mounted) {
                  await showEditProfileSheet(context, user);
                }
              } else if (value == 'password') {
                if (mounted) await showChangePasswordSheet(context);
              } else if (value == 'logout') {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go(Routes.login);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Edit profile')),
              PopupMenuItem(value: 'password', child: Text('Change password')),
              PopupMenuItem(value: 'server', child: Text('Server address')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: _data == null && _loading
          ? const AdminLoadingState()
          : _error != null
          ? AdminEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load $title',
              message: _error!,
              action: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            )
          : Column(
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: switch (_section) {
                      'dashboard' => _dashboard(),
                      'analytics' => _analytics(),
                      'notifications' => _notifications(),
                      _ => _list(),
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton:
          _section == 'categories' ||
              _section == 'products' ||
              _section == 'coupons'
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (_section == 'products') {
                  await _openForm(const ProductFormScreen());
                  return;
                }
                if (_section == 'coupons') {
                  await _openForm(const CouponFormScreen());
                  return;
                }
                final name = await _ask('New category', hint: 'Category name');
                if (name != null) {
                  await _mutate(() async {
                    await _dio.post(
                      '/api/admin/categories',
                      data: {'name': name},
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                _section == 'products'
                    ? 'Add product'
                    : _section == 'coupons'
                    ? 'Add coupon'
                    : 'Add category',
              ),
            )
          : null,
    );
  }

  Widget _navigationDrawer() {
    final user = ref.watch(currentUserProvider);
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOREVER',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Store administration',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                children: [
                  _drawerDestination(
                    'dashboard',
                    'Dashboard',
                    Icons.dashboard_outlined,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 20, 14, 8),
                    child: Text(
                      'MANAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  for (final entry in _sections.entries)
                    _drawerDestination(
                      entry.key,
                      entry.value.$1,
                      entry.value.$2,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.fill,
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Admin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerDestination(String section, String label, IconData icon) {
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: selected ? AppColors.ink : null,
        leading: Icon(
          icon,
          size: 21,
          color: selected ? Colors.white : AppColors.secondaryText,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.go(
            section == 'dashboard' ? Routes.admin : '${Routes.admin}/$section',
          );
        },
      ),
    );
  }

  Widget _dashboard() {
    final stats = Map<String, dynamic>.from(_data as Map);
    final recent = (_recentOrders?['content'] as List? ?? []);
    final statusCounts = (stats['ordersByStatus'] as Map?) ?? {};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'Store overview',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 27),
        ),
        const SizedBox(height: 4),
        const Text(
          'A quick look at what needs your attention.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 0,
              children: [
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    label: 'Revenue',
                    value: '\$${stats['revenue']}',
                    icon: Icons.payments_outlined,
                    hint: 'Excludes cancelled',
                    onTap: () => context.push('${Routes.admin}/analytics'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    label: 'Orders',
                    value: '${stats['totalOrders']}',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => context.push('${Routes.admin}/orders'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    label: 'Products',
                    value: '${stats['activeProducts']}',
                    icon: Icons.checkroom_outlined,
                    hint: '${stats['hiddenProducts']} hidden',
                    onTap: () => context.push('${Routes.admin}/products'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    label: 'Customers',
                    value: '${stats['customers']}',
                    icon: Icons.people_outline,
                    onTap: () => context.push('${Routes.admin}/customers'),
                  ),
                ),
              ],
            );
          },
        ),
        if ((_notificationPreview?['unreadCount'] as num? ?? 0) > 0)
          AdminSurface(
            onTap: () => context.push('${Routes.admin}/notifications'),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_notificationPreview!['unreadCount']} unread notifications',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        AdminSectionHeading(
          'Orders by status',
          action: TextButton(
            onPressed: () => context.push('${Routes.admin}/orders'),
            child: const Text('View all'),
          ),
        ),
        AdminSurface(
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final entry in statusCounts.entries)
                InkWell(
                  onTap: () => context.push(
                    '${Routes.admin}/orders?status=${entry.key}',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AdminStatusBadge('${entry.key}'),
                        const SizedBox(width: 5),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AdminSectionHeading(
          'Recent orders',
          action: TextButton(
            onPressed: () => context.push('${Routes.admin}/orders'),
            child: const Text('View all'),
          ),
        ),
        if (recent.isEmpty)
          const AdminSurface(
            child: Text(
              'No recent orders yet.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          )
        else
          AdminSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(
                      'Order #${recent[i]['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: AdminStatusBadge('${recent[i]['status']}'),
                    trailing: Text(
                      '\$${recent[i]['total']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () =>
                        _showOrder(Map<String, dynamic>.from(recent[i] as Map)),
                  ),
                ],
              ],
            ),
          ),
        AdminSurface(
          onTap: () => context.push('${Routes.admin}/inventory'),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppColors.warning),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Low stock sizes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_analyticsPreview?['lowStockCount'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
        const AdminSectionHeading('Manage store'),
        for (final entry in _sections.entries.take(6))
          AdminSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(entry.value.$2, color: AppColors.text),
              title: Text(
                entry.value.$1,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.push('${Routes.admin}/${entry.key}'),
            ),
          ),
      ],
    );
  }

  Widget _list() {
    final raw = _data;
    final page = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final allRows = (page?['content'] ?? raw) as List<dynamic>;
    final localSearch = _section != 'products' && _section != 'orders';
    final rows = allRows.where((rawRow) {
      final row = rawRow as Map;
      if (_section == 'inventory' && _lowStockOnly && row['lowStock'] != true) {
        return false;
      }
      if (localSearch &&
          _query.isNotEmpty &&
          !row.values.any(
            (value) => '$value'.toLowerCase().contains(_query.toLowerCase()),
          )) {
        return false;
      }
      return true;
    }).toList();
    final activeFilters = [
      _status,
      _category,
      _subCategory,
      _paymentMethod,
      _coupon,
      if (_active != null) 'visibility',
      if (_paid != null) 'paid',
      if (_orderDates != null) 'dates',
      if (_lowStockOnly) 'low stock',
    ].where((item) => item != null).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (_section != 'dashboard')
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search ${_sections[_section]?.$1.toLowerCase()}',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: localSearch
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        _page = 0;
                        _load();
                      },
                    ),
            ),
            onChanged: (value) {
              _query = value.trim();
              if (localSearch) setState(() {});
            },
            onSubmitted: (_) {
              if (!localSearch) {
                _page = 0;
                _load();
              }
            },
          ),
        const SizedBox(height: 12),
        if (_section == 'inventory' ||
            _section == 'products' ||
            _section == 'orders')
          AdminSurface(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              key: ValueKey('filters-$_section'),
              initiallyExpanded: _filtersExpanded,
              onExpansionChanged: (value) => _filtersExpanded = value,
              leading: const Icon(Icons.tune_rounded),
              title: const Text(
                'Filters & sort',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                activeFilters == 0 ? 'Showing all' : '$activeFilters active',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_section == 'inventory')
                        SwitchListTile(
                          title: const Text('Low stock only'),
                          value: _lowStockOnly,
                          onChanged: (value) =>
                              setState(() => _lowStockOnly = value),
                        ),
                      if (_section == 'orders')
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final status in <String?>[
                              null,
                              'ORDER_PLACED',
                              'PAYMENT_PENDING',
                              'SHIPPED',
                              'DELIVERED',
                              'CANCELLED',
                            ])
                              ChoiceChip(
                                label: Text(status ?? 'All'),
                                selected: _status == status,
                                onSelected: (_) {
                                  _status = status;
                                  _page = 0;
                                  _load();
                                },
                              ),
                          ],
                        ),
                      if (_section == 'products')
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final filter in <bool?>[null, true, false])
                              ChoiceChip(
                                label: Text(
                                  filter == null
                                      ? 'All'
                                      : filter
                                      ? 'Visible'
                                      : 'Hidden',
                                ),
                                selected: _active == filter,
                                onSelected: (_) {
                                  _active = filter;
                                  _page = 0;
                                  _load();
                                },
                              ),
                          ],
                        ),
                      if (_section == 'products' || _section == 'orders') ...[
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _sort,
                          isExpanded: true,
                          items: [
                            for (final entry
                                in (_section == 'products'
                                        ? <String, String>{
                                            'newest': 'Newest',
                                            'oldest': 'Oldest',
                                            'name_asc': 'Name A–Z',
                                            'name_desc': 'Name Z–A',
                                            'price_asc': 'Lowest price',
                                            'price_desc': 'Highest price',
                                            'stock_asc': 'Lowest stock',
                                            'stock_desc': 'Highest stock',
                                          }
                                        : <String, String>{
                                            'newest': 'Newest',
                                            'oldest': 'Oldest',
                                            'total_asc': 'Lowest total',
                                            'total_desc': 'Highest total',
                                            'status': 'Status',
                                          })
                                    .entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text('Sort: ${entry.value}'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            _sort = value;
                            _page = 0;
                            _load();
                          },
                        ),
                      ],
                      if (_section == 'products') ...[
                        DropdownButton<String?>(
                          value: _category,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All categories'),
                            ),
                            for (final category in _categoryOptions)
                              DropdownMenuItem(
                                value: '${category['name']}',
                                child: Text('${category['name']}'),
                              ),
                          ],
                          onChanged: _selectCategory,
                        ),
                        if (_category != null)
                          DropdownButton<String?>(
                            value: _subCategory,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All subcategories'),
                              ),
                              for (final sub in _subCategoryOptions)
                                DropdownMenuItem(
                                  value: '${sub['name']}',
                                  child: Text('${sub['name']}'),
                                ),
                            ],
                            onChanged: (value) {
                              _subCategory = value;
                              _page = 0;
                              _load();
                            },
                          ),
                      ],
                      if (_section == 'orders') ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final method in <String?>[null, 'COD', 'KHQR'])
                              ChoiceChip(
                                label: Text(method ?? 'Any payment'),
                                selected: _paymentMethod == method,
                                onSelected: (_) {
                                  _paymentMethod = method;
                                  _page = 0;
                                  _load();
                                },
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final paid in <bool?>[null, true, false])
                              ChoiceChip(
                                label: Text(
                                  paid == null
                                      ? 'Any paid state'
                                      : paid
                                      ? 'Paid'
                                      : 'Unpaid',
                                ),
                                selected: _paid == paid,
                                onSelected: (_) {
                                  _paid = paid;
                                  _page = 0;
                                  _load();
                                },
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: Text(
                                _orderDates == null
                                    ? 'Date range'
                                    : '${_orderDates!.start.toLocal().toString().split(' ').first} – ${_orderDates!.end.toLocal().toString().split(' ').first}',
                              ),
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDateRange: _orderDates,
                                );
                                if (range != null) {
                                  _orderDates = range;
                                  _page = 0;
                                  _load();
                                }
                              },
                            ),
                            if (_orderDates != null)
                              ActionChip(
                                label: const Text('Clear dates'),
                                onPressed: () {
                                  _orderDates = null;
                                  _page = 0;
                                  _load();
                                },
                              ),
                            ActionChip(
                              label: Text(
                                _coupon == null
                                    ? 'Coupon code'
                                    : 'Coupon: $_coupon',
                              ),
                              onPressed: () async {
                                final code = await _ask(
                                  'Filter by coupon',
                                  initial: _coupon ?? '',
                                );
                                _coupon = code;
                                _page = 0;
                                _load();
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${page?['totalElements'] ?? rows.length} ${rows.length == 1 ? 'result' : 'results'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              if (_section == 'products' || _section == 'orders')
                Text(
                  'Page ${_page + 1}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (rows.isEmpty)
          AdminEmptyState(
            title: 'Nothing to show',
            message: _query.isNotEmpty || activeFilters > 0
                ? 'Try a different search or filter.'
                : 'Items will appear here when available.',
            icon: _sections[_section]?.$2 ?? Icons.inbox_outlined,
            action: _query.isNotEmpty || activeFilters > 0
                ? TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  )
                : null,
          ),
        for (final rawRow in rows)
          _row(Map<String, dynamic>.from(rawRow as Map)),
        if (page != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page == 0
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${_page + 1} of ${((page['totalPages'] as num?) ?? 0) < 1 ? 1 : page['totalPages']}',
              ),
              IconButton(
                onPressed: page['last'] == true
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> row) {
    final id = row['id'];
    switch (_section) {
      case 'products':
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: (row['images'] as List? ?? []).isEmpty
                ? Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.muted,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      '${(row['images'] as List).first}',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.fill,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
            title: Text(
              '${row['name']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${row['category']} · \$${row['price']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                AdminStatusBadge(row['active'] == true ? 'Visible' : 'Hidden'),
              ],
            ),
            trailing: Switch(
              value: row['active'] == true,
              onChanged: (active) => _mutate(() async {
                await _dio.patch(
                  '/api/admin/products/$id/active',
                  queryParameters: {'active': active},
                );
              }),
            ),
            onTap: () => _openForm(ProductFormScreen(product: row)),
          ),
        );
      case 'orders':
        final next = (row['nextStatuses'] as List? ?? []).cast<String>();
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$id',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '\$${row['total']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  AdminStatusBadge('${row['status']}'),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _displayDate(row['createdAt']),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: next.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Change status',
                    onSelected: (status) => _changeOrderStatus(row, status),
                    itemBuilder: (_) => [
                      for (final status in next)
                        PopupMenuItem(value: status, child: Text(status)),
                    ],
                  ),
            onTap: () => _showOrder(row),
          ),
        );
      case 'inventory':
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${row['size']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(
              '${row['productName']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Text('${row['stock']} in stock'),
                if (row['lowStock'] == true) ...[
                  const SizedBox(width: 8),
                  const AdminStatusBadge('Low stock'),
                ],
              ],
            ),
            trailing: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.muted,
            ),
            onTap: () async {
              final value = await _ask(
                'Set stock',
                initial: '${row['stock']}',
                hint: 'Quantity',
              );
              final stock = int.tryParse(value ?? '');
              if (stock == null || stock < 0) return;
              await _mutate(() async {
                await _dio.put(
                  '/api/admin/inventory/${row['productId']}/${Uri.encodeComponent('${row['size']}')}',
                  data: {'stock': stock},
                );
              });
            },
          ),
        );
      case 'customers':
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.fill,
              child: Text(
                '${row['name']}'.isEmpty
                    ? '?'
                    : '${row['name']}'[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            title: Text(
              '${row['name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${row['email']}\n${row['orderCount']} orders · \$${row['totalSpent']} spent',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCustomer(row),
          ),
        );
      case 'categories':
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(
              Icons.category_outlined,
              color: AppColors.secondaryText,
            ),
            title: Text(
              '${row['name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${row['productCount']} products'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCategory(row),
          ),
        );
      case 'coupons':
        return AdminSurface(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(
              '${row['code']}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['description'] ?? ''} · Used ${row['timesUsed']} times',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                AdminStatusBadge('${row['status']}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'toggle') {
                  await _mutate(() async {
                    await _dio.patch(
                      '/api/admin/coupons/$id/active',
                      queryParameters: {'active': row['active'] != true},
                    );
                  });
                } else if (action == 'delete') {
                  if (!await _confirm(
                    'Delete coupon?',
                    'Delete ${row['code']}?',
                  )) {
                    return;
                  }
                  await _mutate(() async {
                    await _dio.delete('/api/admin/coupons/$id');
                  });
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    row['active'] == true ? 'Deactivate' : 'Activate',
                  ),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _openForm(CouponFormScreen(coupon: row)),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _displayDate(Object? value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? '$value' : formatDate(parsed.toLocal());
  }

  Future<void> _changeOrderStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    String? reason;
    if (status == 'CANCELLED') {
      reason = await _ask(
        'Cancellation reason',
        hint: 'This will be sent to the customer',
        maxLines: 3,
      );
      if (reason == null) return;
    }
    await _mutate(() async {
      await _dio.patch(
        '/api/admin/orders/${order['id']}/status',
        data: {'status': status, 'reason': ?reason},
      );
    });
  }

  void _showOrder(Map<String, dynamic> order) {
    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : <String, dynamic>{};
    final items = (order['items'] as List? ?? []).cast<Map>();
    final next = (order['nextStatuses'] as List? ?? []).cast<String>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .86,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order['id']}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AdminStatusBadge('${order['status']}'),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _displayDate(order['createdAt']),
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const AdminSectionHeading('Items'),
              AdminSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(
                          '${items[i]['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Size ${items[i]['size']} · Qty ${items[i]['quantity']}',
                        ),
                        trailing: Text(
                          '\$${items[i]['price']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const AdminSectionHeading('Payment summary'),
              AdminSurface(
                child: Column(
                  children: [
                    _detailLine('Items', '\$${order['itemsAmount']}'),
                    _detailLine('Delivery', '\$${order['deliveryFee']}'),
                    if (order['couponCode'] != null)
                      _detailLine(
                        'Coupon ${order['couponCode']}',
                        '−\$${order['discount']}',
                      ),
                    const Divider(height: 22),
                    _detailLine(
                      'Total',
                      '\$${order['total']}',
                      prominent: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AdminStatusBadge(
                          order['paid'] == true ? 'Paid' : 'Unpaid',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order['paymentMethod']}',
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const AdminSectionHeading('Shipping address'),
              AdminSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address['firstName'] ?? ''} ${address['lastName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['zipcode'] ?? ''}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${address['phone'] ?? ''} · ${address['email'] ?? ''}',
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              if (order['cancelReason'] != null)
                AdminSurface(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Cancellation: ${order['cancelReason']}'),
                      ),
                    ],
                  ),
                ),
              if (next.isNotEmpty) ...[
                const AdminSectionHeading('Update status'),
                for (final status in next)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(status.replaceAll('_', ' ')),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _changeOrderStatus(order, status);
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value, {bool prominent = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: prominent ? AppColors.ink : AppColors.secondaryText,
                  fontWeight: prominent ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
                  fontSize: prominent ? 18 : 14,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _showCustomer(Map<String, dynamic> customer) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/admin/customers/${customer['id']}/orders',
        queryParameters: {'size': 50},
      );
      if (!mounted) return;
      final orders = (response.data?['content'] as List? ?? []).cast<Map>();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .78,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  '${customer['name']}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                AdminSurface(
                  child: Column(
                    children: [
                      _detailLine('Email', '${customer['email']}'),
                      if (customer['phone'] != null)
                        _detailLine('Phone', '${customer['phone']}'),
                      _detailLine('Orders', '${customer['orderCount']}'),
                      _detailLine(
                        'Total spent',
                        '\$${customer['totalSpent']}',
                        prominent: true,
                      ),
                    ],
                  ),
                ),
                const AdminSectionHeading('Orders'),
                if (orders.isEmpty)
                  const AdminEmptyState(
                    title: 'No orders yet',
                    message: 'This customer has not placed an order.',
                  ),
                for (final order in orders)
                  AdminSurface(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(
                        'Order #${order['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: AdminStatusBadge('${order['status']}'),
                      trailing: Text(
                        '\$${order['total']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showOrder(Map<String, dynamic>.from(order));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<void> _showCategory(Map<String, dynamic> category) async {
    Future<List<Map<String, dynamic>>> load() async {
      final result = await _dio.get<List<dynamic>>(
        '/api/admin/categories/${category['id']}/sub-categories',
      );
      return (result.data ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    try {
      var subs = await load();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, update) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${category['name']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('${category['productCount']} products'),
                Wrap(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Rename'),
                      onPressed: () async {
                        final name = await _ask(
                          'Rename category',
                          initial: '${category['name']}',
                        );
                        if (name == null) return;
                        await _mutate(() async {
                          await _dio.put(
                            '/api/admin/categories/${category['id']}',
                            data: {'name': name},
                          );
                        });
                        update(() => category['name'] = name);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add subcategory'),
                      onPressed: () async {
                        final name = await _ask('New subcategory');
                        if (name == null) return;
                        try {
                          await _dio.post(
                            '/api/admin/categories/${category['id']}/sub-categories',
                            data: {'name': name},
                          );
                          subs = await load();
                          update(() {});
                        } on DioException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_message(e))),
                            );
                          }
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete category'),
                      onPressed: () async {
                        final categories = ((_data as List).cast<Map>())
                            .where((c) => c['id'] != category['id'])
                            .toList();
                        final hasProducts =
                            (category['productCount'] as num? ?? 0) > 0;
                        final target = hasProducts
                            ? await _chooseTarget(
                                'Move products to',
                                categories,
                              )
                            : null;
                        if (hasProducts && target == null) return;
                        if (!await _confirm(
                          'Delete category?',
                          hasProducts
                              ? 'Its products will move to the selected category.'
                              : 'Remove this empty category?',
                        )) {
                          return;
                        }
                        try {
                          await _dio.delete(
                            '/api/admin/categories/${category['id']}',
                            queryParameters: {'moveTo': ?target},
                          );
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          await _load();
                        } on DioException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_message(e))),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                if (subs.isEmpty) const Text('No subcategories'),
                for (final sub in subs)
                  ListTile(
                    title: Text('${sub['name']}'),
                    subtitle: Text('${sub['productCount']} products'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'rename') {
                          final name = await _ask(
                            'Rename subcategory',
                            initial: '${sub['name']}',
                          );
                          if (name == null) return;
                          try {
                            await _dio.put(
                              '/api/admin/sub-categories/${sub['id']}',
                              data: {'name': name},
                            );
                            subs = await load();
                            update(() {});
                          } on DioException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_message(e))),
                              );
                            }
                          }
                        } else if (action == 'delete') {
                          final hasProducts =
                              (sub['productCount'] as num? ?? 0) > 0;
                          final target = hasProducts
                              ? await _chooseTarget(
                                  'Move products to',
                                  subs
                                      .where((s) => s['id'] != sub['id'])
                                      .toList(),
                                )
                              : null;
                          if (hasProducts && target == null) return;
                          if (!await _confirm(
                            'Delete subcategory?',
                            hasProducts
                                ? 'Its products will move to the selected subcategory.'
                                : 'Remove this empty subcategory?',
                          )) {
                            return;
                          }
                          try {
                            await _dio.delete(
                              '/api/admin/sub-categories/${sub['id']}',
                              queryParameters: {'moveTo': ?target},
                            );
                            subs = await load();
                            update(() {});
                          } on DioException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_message(e))),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (mounted) _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<Object?> _chooseTarget(String title, List<Map> options) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add another category or subcategory before moving products.',
          ),
        ),
      );
      return null;
    }
    Object? selected;
    return showDialog<Object>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<Object>(
            decoration: const InputDecoration(labelText: 'Destination'),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option['id'] as Object,
                  child: Text('${option['name']}'),
                ),
            ],
            onChanged: (value) => update(() => selected = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analytics() {
    final data = Map<String, dynamic>.from(_data as Map);
    final revenue = (data['revenueByDay'] as List? ?? []).cast<Map>();
    final products = (data['topProducts'] as List? ?? []).cast<Map>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'Store performance',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 27),
        ),
        const SizedBox(height: 4),
        const Text(
          'Recent sales and products customers love.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 18),
        AdminRevenueChart(days: revenue),
        AdminSurface(
          onTap: () => context.push('${Routes.admin}/inventory'),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Low stock sizes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${data['lowStockCount']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
        const AdminSectionHeading('Top products'),
        if (products.isEmpty)
          const AdminEmptyState(
            title: 'No sales yet',
            message: 'Top products will appear when orders are placed.',
          ),
        for (var i = 0; i < products.length; i++)
          AdminSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.fill,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                '${products[i]['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${products[i]['quantity']} sold'),
              trailing: Text(
                '\$${products[i]['revenue']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        const AdminSectionHeading('Daily revenue'),
        if (revenue.isEmpty)
          const AdminEmptyState(
            title: 'No revenue to show',
            message: 'Daily totals will appear after sales.',
          ),
        for (final day in revenue.reversed)
          AdminSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text('${day['day']}'),
              trailing: Text(
                '\$${day['revenue']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _notifications() {
    final data = Map<String, dynamic>.from(_data as Map);
    final items = (data['items'] as List? ?? []).cast<Map>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'Activity',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 27),
        ),
        const SizedBox(height: 4),
        const Text(
          'Orders, customers, and stock updates.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        AdminSectionHeading(
          '${data['unreadCount']} unread',
          action: TextButton(
            onPressed: () => _mutate(() async {
              await _dio.post('/api/admin/notifications/read-all');
            }),
            child: const Text('Mark all read'),
          ),
        ),
        if (items.isEmpty)
          const AdminEmptyState(
            title: 'All caught up',
            message: 'New store activity will appear here.',
            icon: Icons.notifications_none_outlined,
          ),
        for (final item in items)
          AdminSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text(
                '${item['title']}',
                style: TextStyle(
                  fontWeight: item['read'] == true
                      ? FontWeight.w500
                      : FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${item['message']}\n${_displayDate(item['createdAt'])}',
              ),
              isThreeLine: true,
              leading: Icon(
                item['read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
                color: item['read'] == true
                    ? AppColors.muted
                    : AppColors.accent,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () async {
                await _mutate(() async {
                  await _dio.post(
                    '/api/admin/notifications/${item['id']}/read',
                  );
                });
                final link = Uri.tryParse('${item['link'] ?? ''}');
                if (mounted &&
                    link != null &&
                    link.path.startsWith('${Routes.admin}/')) {
                  context.go(link.toString());
                }
              },
            ),
          ),
      ],
    );
  }
}
