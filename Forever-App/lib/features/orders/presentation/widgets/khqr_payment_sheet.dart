import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/khqr_payment.dart';
import '../providers/order_providers.dart';

const _khqrRed = Color(0xFFE1232E);
const _pollEvery = Duration(seconds: 3);

/// Shows the KHQR code until Bakong reports the payment. Resolves to whether the order was paid;
/// when it was not, the order has been cancelled and its items are back in the cart.
Future<bool> showKhqrPaymentSheet(
  BuildContext context,
  KhqrPayment payment,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      builder: (_) => _KhqrPaymentSheet(payment: payment),
    ) ??
    false;

class _KhqrPaymentSheet extends ConsumerStatefulWidget {
  const _KhqrPaymentSheet({required this.payment});

  final KhqrPayment payment;

  @override
  ConsumerState<_KhqrPaymentSheet> createState() => _KhqrPaymentSheetState();
}

class _KhqrPaymentSheetState extends ConsumerState<_KhqrPaymentSheet> {
  late final _qr = widget.payment.qrBytes;
  Timer? _clock;
  bool _closing = false;
  // Set once there is an outcome, so polling and cancelling never both pop the sheet.
  bool _finished = false;

  Duration get _left {
    final left = widget.payment.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left == Duration.zero) {
        _cancel();
      } else {
        setState(() {});
      }
    });
    _poll();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _finished = true;
    super.dispose();
  }

  Future<void> _poll() async {
    final orders = ref.read(ordersControllerProvider.notifier);
    while (!_finished) {
      await Future<void>.delayed(_pollEvery);
      if (_finished) return;
      try {
        if (await orders.verifyKhqr(widget.payment.orderId)) _finish(true);
      } catch (_) {
        // Bakong can be briefly unreachable; keep checking until the code expires.
      }
    }
  }

  Future<void> _cancel() async {
    if (_finished || _closing) return;
    setState(() => _closing = true);
    var paid = false;
    try {
      // The API checks Bakong first, so a payment made at the last second is kept.
      paid = await ref
          .read(ordersControllerProvider.notifier)
          .cancelKhqr(widget.payment.orderId);
    } catch (_) {}
    _finish(paid);
  }

  void _finish(bool paid) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(paid);
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final minutes = left.inMinutes;
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Scan to pay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cancel payment',
                    onPressed: _closing ? null : _cancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 260,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 16),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: _khqrRed,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Text(
                        'KHQR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.payment.merchantName,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          Text.rich(
                            TextSpan(
                              text: widget.payment.amount.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: ' ${widget.payment.currency}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 20, endIndent: 20, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.memory(
                        _qr,
                        width: 232,
                        height: 232,
                        filterQuality: FilterQuality.none,
                        semanticLabel: 'KHQR payment code',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scan with Bakong or any Cambodian banking app (ABA, ACLEDA, Wing…).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 4),
              Text(
                _closing
                    ? 'Closing…'
                    : 'Waiting for payment · code expires in $minutes:$seconds',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _closing ? null : _cancel,
                  child: const Text('Cancel payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
