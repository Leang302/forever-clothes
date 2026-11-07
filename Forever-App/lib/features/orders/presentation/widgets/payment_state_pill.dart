import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/order.dart';

/// "Paid" / "Awaiting payment" / "Pay on delivery" / "Not paid".
class PaymentStatePill extends StatelessWidget {
  const PaymentStatePill(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final state = order.paymentState;
    return StatusPill(
      state.label,
      key: Key('payment-state-${order.id}'),
      color: switch (state) {
        PaymentState.paid => AppColors.success,
        PaymentState.awaitingPayment => AppColors.warning,
        PaymentState.payOnDelivery => AppColors.info,
        PaymentState.notPaid => AppColors.danger,
      },
    );
  }
}
