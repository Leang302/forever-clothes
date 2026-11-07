import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/haptics.dart';

/// Pill-shaped selectable chip (categories, sizes, filters).
///
/// A disabled chip (e.g. a sold-out size) is still shown, struck through and
/// greyed, but cannot be tapped.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 0,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                Haptics.tap();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.ink
                : (enabled ? AppColors.surface : AppColors.fill),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: active ? AppColors.ink : AppColors.line),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : (enabled ? AppColors.text : AppColors.muted),
              fontWeight: FontWeight.w600,
              decoration: enabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}
