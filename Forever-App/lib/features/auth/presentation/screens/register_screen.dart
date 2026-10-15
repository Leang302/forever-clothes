import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.redirect});

  final String? redirect;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
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
          .register(_name.text, _email.text, _password.text);
      if (!mounted) return;
      final redirect = widget.redirect == null
          ? ''
          : '&redirect=${Uri.encodeComponent(widget.redirect!)}';
      context.push(
        '${Routes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}$redirect',
      );
    } catch (e) {
      Haptics.error();
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Join Forever and get your first order delivered to your door.',
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Log in',
        onTap: () => context.pushReplacement(
          widget.redirect == null
              ? Routes.login
              : '${Routes.login}?redirect=${Uri.encodeComponent(widget.redirect!)}',
        ),
      ),
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AuthTextField(
                controller: _name,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                validator: Validators.required,
                capitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 14),
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
                label: 'Password (min 8 characters)',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                validator: Validators.newPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Create account', loading: _busy, onPressed: _submit),
      ],
    );
  }
}
