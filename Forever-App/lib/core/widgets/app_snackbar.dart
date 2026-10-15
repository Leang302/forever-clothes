import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../error/app_exception.dart';

/// Floating toasts. Scaffold already lifts them above the bottom bar (navigation bar / action bar).
abstract final class AppSnackbar {
  static const _margin = EdgeInsets.fromLTRB(20, 0, 20, 12);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.ink, Icons.check_circle_outline);

  static void error(BuildContext context, Object error) =>
      _show(context, errorText(error), AppColors.danger, Icons.error_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          margin: _margin,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
