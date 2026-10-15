import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/haptics.dart';

/// 44pt round white button used in custom headers and over images.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                child: Icon(icon, size: 22, color: AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
