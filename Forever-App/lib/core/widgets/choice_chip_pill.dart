import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/haptics.dart';

/// Pill-shaped selectable chip (categories, sizes, filters).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
