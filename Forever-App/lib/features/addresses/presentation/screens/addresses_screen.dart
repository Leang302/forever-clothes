import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/address_providers.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesControllerProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add address'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.profile),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'My addresses',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Expanded(
              child: addresses.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.location_on_outlined,
                        title: 'No saved addresses',
                        message: 'Save an address to reuse it at checkout.',
                        actionLabel: 'Add address',
                        onAction: () => _addAddress(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _AddressCard(list[i]),
                      ),
                loading: () => Skeletonizer(
                  enabled: true,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: 2,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, _) => const _AddressCard(_skeleton),
                  ),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(addressesControllerProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAddress(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const _AddAddressSheet(),
    );
    if (saved == true && context.mounted) {
      AppSnackbar.info(context, 'Address saved');
    }
  }

  static const _skeleton = SavedAddress(
    id: 0,
    label: 'Home',
    firstName: 'A',
    lastName: 'B',
    email: 'a@b.c',
    street: 'Loading street address',
    city: 'City',
    state: 'State',
    zipcode: '0',
    country: 'Country',
    phone: '0',
  );
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard(this.address);

  final SavedAddress address;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${address.label}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(addressesControllerProvider.notifier).remove(address.id);
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${address.firstName} ${address.lastName}'),
                Text(
                  '${address.street}, ${address.city}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                Text(
                  '${address.state} ${address.zipcode}, ${address.country}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  address.phone,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.danger,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _label,
      _firstName,
      _lastName,
      _email,
      _street,
      _city,
      _state,
      _zip,
      _country,
      _phone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? type,
    bool last = false,
    bool email = false,
    TextCapitalization caps = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      textCapitalization: email ? TextCapitalization.none : caps,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return 'Required';
        if (email && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(addressesControllerProvider.notifier)
          .add(
            label: _label.text.trim(),
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            street: _street.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            zipcode: _zip.text.trim(),
            country: _country.text.trim(),
            phone: _phone.text.trim(),
          );
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
        20,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add address',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              _field(_label, 'Label (e.g. Home)'),
              const SizedBox(height: 14),
              _pair(
                _field(_firstName, 'First name'),
                _field(_lastName, 'Last name'),
              ),
              const SizedBox(height: 14),
              _field(
                _email,
                'Email',
                type: TextInputType.emailAddress,
                email: true,
              ),
              const SizedBox(height: 14),
              _field(_street, 'Street address'),
              const SizedBox(height: 14),
              _pair(_field(_city, 'City'), _field(_state, 'State / province')),
              const SizedBox(height: 14),
              _pair(
                _field(_zip, 'Zip code', type: TextInputType.number),
                _field(_country, 'Country'),
              ),
              const SizedBox(height: 14),
              _field(
                _phone,
                'Phone number',
                type: TextInputType.phone,
                last: true,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Save address',
                loading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
