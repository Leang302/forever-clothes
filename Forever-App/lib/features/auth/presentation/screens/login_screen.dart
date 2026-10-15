import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirect});

  final String? redirect;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
      // go_router does not redirect pushed screens, so leave explicitly.
      if (mounted) {
        final user = ref.read(authControllerProvider).value;
        context.go(
          user?.isAdmin == true
              ? Routes.admin
              : (widget.redirect ?? Routes.home),
        );
      }
    } on AppException catch (e) {
      Haptics.error();
      if (!mounted) return;
      if (e.isUnverifiedEmail) {
        AppSnackbar.info(context, e.message);
        final redirect = widget.redirect == null
            ? ''
            : '&redirect=${Uri.encodeComponent(widget.redirect!)}';
        context.push(
          '${Routes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}$redirect',
        );
      } else {
        AppSnackbar.error(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to track orders and check out faster.',
      footer: AuthFooterLink(
        prompt: 'New to Forever?',
        action: 'Create account',
        onTap: () => context.pushReplacement(
          widget.redirect == null
              ? Routes.register
              : '${Routes.register}?redirect=${Uri.encodeComponent(widget.redirect!)}',
        ),
      ),
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AuthTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                validator: Validators.required,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(Routes.forgotPassword),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 8),
        AppButton(label: 'Log in', loading: _busy, onPressed: _submit),
      ],
    );
  }
}
