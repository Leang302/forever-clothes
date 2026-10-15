import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/order.dart';

/// Three-step tracker: placed -> shipped -> delivered.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});

  final OrderStatus status;

  static const _steps = [
    OrderStatus.orderPlaced,
    OrderStatus.shipped,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.ink : AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i != _steps.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
