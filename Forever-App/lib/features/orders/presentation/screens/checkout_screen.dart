import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../cart/presentation/widgets/cart_summary.dart';
import '../../domain/entities/order.dart';
import '../providers/order_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  PaymentMethod _method = PaymentMethod.cod;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final parts = user.name.trim().split(RegExp(r'\s+'));
      _firstName.text = parts.first;
      _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _email.text = user.email;
      _phone.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
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

  Future<void> _place() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersControllerProvider.notifier)
          .place(
            paymentMethod: _method,
            address: ShippingAddress(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              email: _email.text.trim(),
              street: _street.text.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              zipcode: _zip.text.trim(),
              country: _country.text.trim(),
              phone: _phone.text.trim(),
            ),
          );
      Haptics.success();
      if (!mounted) return;
      context.go(Routes.orders);
      AppSnackbar.info(context, 'Order placed. Thank you!');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.cart),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Checkout',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Delivery address',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
              const SizedBox(height: 28),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _PaymentTile(
                title: 'Cash on delivery',
                subtitle: 'Pay when your order arrives',
                icon: Icons.payments_outlined,
                selected: _method == PaymentMethod.cod,
                onTap: () => setState(() => _method = PaymentMethod.cod),
              ),
              const SizedBox(height: 10),
              const _PaymentTile(
                title: 'Stripe',
                subtitle: 'Coming soon',
                icon: Icons.credit_card_rounded,
                selected: false,
                enabled: false,
              ),
              const SizedBox(height: 10),
              const _PaymentTile(
                title: 'Razorpay',
                subtitle: 'Coming soon',
                icon: Icons.account_balance_wallet_outlined,
                selected: false,
                enabled: false,
              ),
              const SizedBox(height: 28),
              if (cart != null) CartSummary(cart: cart, shadow: false),
              const SizedBox(height: 16),
              AppButton(
                label: 'Place order',
                icon: Icons.check_rounded,
                loading: _busy,
                onPressed: (cart == null || cart.isEmpty) ? null : _place,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.ink : AppColors.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
