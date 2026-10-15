import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(_email.text);
      if (mounted) {
        context.push(
          '${Routes.resetPassword}?email=${Uri.encodeComponent(_email.text.trim())}',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password?',
      subtitle:
          'Enter the email you registered with and we will send you a code to reset it.',
      children: [
        Form(
          key: _form,
          child: AuthTextField(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Send code', loading: _busy, onPressed: _submit),
      ],
    );
  }
}
