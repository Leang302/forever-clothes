import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_input.dart';
import '../widgets/resend_button.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.redirect});

  final String email;
  final String? redirect;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _otp = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.text.length < 6 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(widget.email, _otp.text);
      Haptics.success();
      // go_router does not redirect pushed screens, so leave explicitly (this also drops login/register below).
      if (mounted) context.go(widget.redirect ?? Routes.home);
    } catch (e) {
      Haptics.error();
      _otp.clear();
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendOtp(widget.email, OtpPurpose.verifyEmail);
      if (mounted) AppSnackbar.info(context, 'A new code is on its way');
    } on AppException catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Check your inbox',
      subtitle:
          'We sent a 6-digit code to ${widget.email}. Enter it below to verify your email.',
      children: [
        OtpInput(controller: _otp, onCompleted: (_) => _verify()),
        const SizedBox(height: 32),
        AppButton(label: 'Verify', loading: _busy, onPressed: _verify),
        const SizedBox(height: 8),
        Center(child: ResendButton(onResend: _resend)),
      ],
    );
  }
}
