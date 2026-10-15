import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input.dart';
import '../widgets/resend_button.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_otp.text.length < 6) {
      AppSnackbar.info(context, 'Enter the 6-digit code from your email');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(widget.email, _otp.text, _password.text);
      if (!mounted) return;
      context.go(Routes.login);
      AppSnackbar.info(context, 'Password updated. Please log in.');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendOtp(widget.email, OtpPurpose.resetPassword);
      if (mounted) AppSnackbar.info(context, 'A new code is on its way');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle:
          'Enter the code sent to ${widget.email} and choose a new password.',
      children: [
        OtpInput(controller: _otp),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: AuthTextField(
            controller: _password,
            label: 'New password (min 8 characters)',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            validator: Validators.newPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Reset password', loading: _busy, onPressed: _submit),
        const SizedBox(height: 8),
        Center(child: ResendButton(onResend: _resend)),
      ],
    );
  }
}
