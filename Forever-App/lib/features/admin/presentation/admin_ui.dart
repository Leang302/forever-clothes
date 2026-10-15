import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Shared visual language for the mobile admin screens.
class AdminSurface extends StatelessWidget {
  const AdminSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class AdminSectionHeading extends StatelessWidget {
  const AdminSectionHeading(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'DELIVERED' ||
      'ACTIVE' ||
      'Visible' ||
      'Paid' => (const Color(0xFFE7F5EC), const Color(0xFF207449)),
      'CANCELLED' ||
      'EXPIRED' ||
      'Hidden' => (const Color(0xFFF2F0EE), const Color(0xFF66615B)),
      'LOW' ||
      'Low stock' ||
      'USED_UP' => (const Color(0xFFFFF1DF), const Color(0xFF96600F)),
      'SHIPPED' ||
      'SCHEDULED' => (const Color(0xFFEAF2FF), const Color(0xFF3266A5)),
      _ => (const Color(0xFFF5EAF0), const Color(0xFF8C4E6E)),
    };
    final label = status.replaceAll('_', ' ').toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AdminSurface(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(icon, size: 19, color: AppColors.muted),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
    child: Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 30, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SizedBox(height: 8),
      for (var i = 0; i < 4; i++)
        AdminSurface(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: AppColors.fill,
                    ),
                    const SizedBox(height: 10),
                    Container(height: 10, width: 120, color: AppColors.fill),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class AdminRevenueChart extends StatelessWidget {
  const AdminRevenueChart({super.key, required this.days});

  final List<Map> days;

  @override
  Widget build(BuildContext context) {
    final visible = days.length <= 7 ? days : days.sublist(days.length - 7);
    final values = visible
        .map((day) => double.tryParse('${day['revenue']}') ?? 0)
        .toList();
    final top = values.fold<double>(
      1,
      (max, value) => value > max ? value : max,
    );
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue over time',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < visible.length; i++)
                  Expanded(
                    child: Semantics(
                      label: '${visible[i]['day']}: \$${visible[i]['revenue']}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: (values[i] / top).clamp(.04, 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: i == visible.length - 1
                                          ? AppColors.accent
                                          : AppColors.ink,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${visible[i]['day']}'.split('-').last,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
