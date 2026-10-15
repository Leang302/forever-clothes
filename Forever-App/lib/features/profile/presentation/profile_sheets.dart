import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';

// Each sheet/dialog owns (and disposes) its own controllers. Disposing them in the opener right after
// `await showModal...` breaks the exit animation, which still paints the text fields.

/// Resolves to `true` when the profile was saved.
Future<bool?> showEditProfileSheet(BuildContext context, AppUser user) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator:
          true, // the floating nav bar lives above the tab navigators
      builder: (_) => EditProfileSheet(user: user),
    );

/// Resolves to `true` when the password was changed.
Future<bool?> showChangePasswordSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const ChangePasswordSheet(),
    );

/// Resolves to the new address ('' means "reset to default"), or null if cancelled.
Future<String?> showServerAddressDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (_) => ServerAddressDialog(current: current),
    );

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Edit profile',
      action: 'Save',
      formKey: _form,
      fields: [
        AuthTextField(
          controller: _name,
          label: 'Full name',
          icon: Icons.person_outline_rounded,
          validator: Validators.required,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _phone,
          label: 'Phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
        ),
      ],
      onSubmit: () async {
        await ref
            .read(authControllerProvider.notifier)
            .updateProfile(_name.text, _phone.text);
      },
    );
  }
}

class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Change password',
      action: 'Update password',
      formKey: _form,
      fields: [
        AuthTextField(
          controller: _current,
          label: 'Current password',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          validator: Validators.required,
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _next,
          label: 'New password (min 8)',
          icon: Icons.lock_reset_rounded,
          obscure: true,
          validator: Validators.newPassword,
          textInputAction: TextInputAction.done,
        ),
      ],
      onSubmit: () async {
        await ref
            .read(authControllerProvider.notifier)
            .changePassword(_current.text, _next.text);
      },
    );
  }
}

class ServerAddressDialog extends ConsumerStatefulWidget {
  const ServerAddressDialog({super.key, required this.current});

  final String current;

  @override
  ConsumerState<ServerAddressDialog> createState() =>
      _ServerAddressDialogState();
}

class _ServerAddressDialogState extends ConsumerState<ServerAddressDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:8989',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "On a real phone use your computer's LAN address. The Android emulator reaches it at http://10.0.2.2:8989.",
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Persists the chosen server address (the Dio client and session rebuild from [baseUrlProvider]).
Future<void> applyServerAddress(WidgetRef ref, String address) =>
    ref.read(baseUrlProvider.notifier).change(address);

/// Bottom-sheet frame: keeps itself above the keyboard, validates, shows [onSubmit] errors, pops `true` on success.
class _FormSheet extends StatefulWidget {
  const _FormSheet({
    required this.title,
    required this.action,
    required this.formKey,
    required this.fields,
    required this.onSubmit,
  });

  final String title;
  final String action;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final Future<void> Function() onSubmit;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ...widget.fields,
            const SizedBox(height: 22),
            AppButton(label: widget.action, loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
