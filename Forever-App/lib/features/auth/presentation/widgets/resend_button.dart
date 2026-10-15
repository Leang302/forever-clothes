import 'dart:async';

import 'package:flutter/material.dart';

/// "Resend code in 42s" button that re-arms its countdown after each resend.
class ResendButton extends StatefulWidget {
  const ResendButton({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 60,
  });

  final Future<void> Function() onResend;
  final int cooldownSeconds;

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  Timer? _timer;
  late int _remaining = widget.cooldownSeconds;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _remaining = widget.cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) t.cancel();
      if (mounted) setState(() => _remaining--);
    });
  }

  Future<void> _resend() async {
    await widget.onResend();
    if (mounted) _start();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _remaining > 0 ? null : _resend,
      child: Text(
        _remaining > 0 ? 'Resend code in ${_remaining}s' : 'Resend code',
      ),
    );
  }
}
