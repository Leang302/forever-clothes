import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../error/app_exception.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is AppException && (error as AppException).isNetwork;
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? 'You seem to be offline' : 'Something went wrong',
      message: errorText(error),
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(160, 50)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
