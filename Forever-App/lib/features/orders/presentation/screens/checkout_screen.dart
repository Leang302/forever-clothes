import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../addresses/domain/entities/saved_address.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../cart/presentation/widgets/cart_summary.dart';
import '../../domain/entities/order.dart';
import '../providers/order_providers.dart';
import '../widgets/khqr_payment_sheet.dart';

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
  final _coupon = TextEditingController();
  final _addressLabel = TextEditingController(text: 'Home');

  PaymentMethod _method = PaymentMethod.cod;
  String? _shippingMethod;
  int? _selectedAddressId;
  bool _saveAddress = false;
  bool _busy = false;
  bool _checkingCoupon = false;
  CouponPreview? _couponPreview;
  String? _couponError;

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
    // Prefill from the first saved address, same as the web app.
    Future.microtask(() {
      final addresses = ref.read(addressesControllerProvider).value;
      if (addresses != null && addresses.isNotEmpty && mounted) {
        _applyAddress(addresses.first);
      }
    });
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
      _coupon,
      _addressLabel,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyAddress(SavedAddress a) {
    setState(() {
      _firstName.text = a.firstName;
      _lastName.text = a.lastName;
      _email.text = a.email;
      _street.text = a.street;
      _city.text = a.city;
      _state.text = a.state;
      _zip.text = a.zipcode;
      _country.text = a.country;
      _phone.text = a.phone;
      _selectedAddressId = a.id;
      _saveAddress = false;
    });
  }

  void _onFieldEdited() {
    if (_selectedAddressId != null) setState(() => _selectedAddressId = null);
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;
    final subtotal = ref.read(cartControllerProvider).value?.subtotal ?? 0;
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final preview = await ref
          .read(orderRepositoryProvider)
          .checkCoupon(code, subtotal);
      if (mounted) setState(() => _couponPreview = preview);
    } catch (e) {
      if (mounted) {
        setState(() {
          _couponPreview = null;
          _couponError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() => _busy = true);
    final address = ShippingAddress(
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
    final orders = ref.read(ordersControllerProvider.notifier);
    try {
      if (_saveAddress) {
        final saved = await ref
            .read(addressesControllerProvider.notifier)
            .add(
              label: _addressLabel.text.trim(),
              firstName: address.firstName,
              lastName: address.lastName,
              email: address.email,
              street: address.street,
              city: address.city,
              state: address.state,
              zipcode: address.zipcode,
              country: address.country,
              phone: address.phone,
            );
        if (mounted) {
          setState(() {
            _selectedAddressId = saved.id;
            _saveAddress = false;
          });
        }
      }
      final couponCode = _couponPreview?.code;
      if (_method == PaymentMethod.khqr) {
        final payment = await orders.startKhqr(
          address,
          couponCode: couponCode,
          shippingMethod: _shippingMethod,
        );
        if (!mounted) return;
        if (!await showKhqrPaymentSheet(context, payment)) {
          if (mounted) {
            AppSnackbar.info(
              context,
              'Payment not completed. Your items are back in your cart',
            );
          }
          return;
        }
      } else {
        await orders.place(
          paymentMethod: _method,
          address: address,
          couponCode: couponCode,
          shippingMethod: _shippingMethod,
        );
      }
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
      onChanged: (_) => _onFieldEdited(),
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
    final addresses = ref.watch(addressesControllerProvider).value ?? const [];
    final shippingOptions =
        ref.watch(checkoutOptionsProvider).value ?? const [];
    if (shippingOptions.isNotEmpty && _shippingMethod == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shippingMethod == null) {
          setState(() => _shippingMethod = shippingOptions.first.code);
        }
      });
    }
    final selectedShipping = shippingOptions
        .where((o) => o.code == _shippingMethod)
        .firstOrNull;
    final discount = _couponPreview?.discount ?? 0.0;

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
              if (addresses.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _SavedAddressChip(
                      address: addresses[i],
                      selected: addresses[i].id == _selectedAddressId,
                      onTap: () => _applyAddress(addresses[i]),
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _saveAddress,
                onChanged: (v) => setState(() {
                  _saveAddress = v ?? false;
                  if (_saveAddress) _selectedAddressId = null;
                }),
                title: const Text('Save this address for next time'),
              ),
              if (_saveAddress) ...[
                const SizedBox(height: 4),
                _field(_addressLabel, 'Address label, e.g. Home', last: true),
              ],
              const SizedBox(height: 28),
              if (shippingOptions.isNotEmpty) ...[
                Text(
                  'Shipping method',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                for (final option in shippingOptions) ...[
                  _ShippingTile(
                    option: option,
                    selected: option.code == _shippingMethod,
                    onTap: () => setState(() => _shippingMethod = option.code),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
              ],
              Text(
                'Coupon code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _coupon,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Optional coupon code',
                      ),
                      onChanged: (_) => setState(() {
                        _couponPreview = null;
                        _couponError = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed:
                          (_checkingCoupon || _coupon.text.trim().isEmpty)
                          ? null
                          : _applyCoupon,
                      child: _checkingCoupon
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ),
                ],
              ),
              if (_couponPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_couponPreview!.summary} — you save '
                    '${_couponPreview!.discount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (_couponError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _couponError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
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
              _PaymentTile(
                title: 'KHQR',
                subtitle: 'Scan with Bakong or any Cambodian banking app',
                icon: Icons.qr_code_2_rounded,
                selected: _method == PaymentMethod.khqr,
                onTap: () => setState(() => _method = PaymentMethod.khqr),
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
              if (cart != null)
                CartSummary(
                  cart: cart,
                  shadow: false,
                  discount: discount,
                  couponCode: _couponPreview?.code,
                  shippingLabel: selectedShipping?.name,
                  deliveryFeeOverride: selectedShipping?.fee,
                ),
              const SizedBox(height: 16),
              AppButton(
                label: _method == PaymentMethod.khqr
                    ? 'Pay with KHQR'
                    : 'Place order',
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

class _SavedAddressChip extends StatelessWidget {
  const _SavedAddressChip({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${address.street}, ${address.city}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShippingTile extends StatelessWidget {
  const _ShippingTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ShippingOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    option.estimate,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              option.fee.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
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
