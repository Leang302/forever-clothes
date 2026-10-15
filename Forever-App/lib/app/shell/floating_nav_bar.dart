import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/presentation/providers/cart_providers.dart';
import '../theme/app_colors.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home_rounded),
  _Destination('Shop', Icons.grid_view_outlined, Icons.grid_view_rounded),
  _Destination('Cart', Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
  _Destination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Pill-shaped navigation bar floating above the content; the selected tab expands to show its label.
class FloatingNavBar extends ConsumerWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const height = 66.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _destinations.length; i++)
                _NavItem(
                  destination: _destinations[i],
                  selected: i == currentIndex,
                  badge: i == 2 ? cartCount : 0,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      offset: const Offset(6, -6),
      child: Icon(
        selected ? destination.activeIcon : destination.icon,
        size: 24,
        color: selected ? Colors.white : AppColors.muted,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          destination.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
