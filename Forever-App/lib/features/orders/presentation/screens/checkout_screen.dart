import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/error/app_exception.dart';
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

/// Validation of one checkout address field (limits mirror the API's).
String? checkoutFieldError(
  String? value, {
  bool email = false,
  bool phone = false,
  int max = 100,
}) {
  final t = value?.trim() ?? '';
  if (t.isEmpty) return 'Required';
  if (t.length > max) return 'Use at most $max characters';
  if (email && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(t)) {
    return 'Enter a valid email';
  }
  if (phone) {
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9 ()\-.]+$').hasMatch(t) ||
        digits.length < 6 ||
        digits.length > 15) {
      return 'Enter a valid phone number';
    }
  }
  return null;
}

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

  /// Generated once per checkout attempt and resent unchanged on an
  /// identical retry, so a resubmission after a failed/ambiguous request
  /// (e.g. timeout) can't create a duplicate order server-side. If the
  /// shopper changes anything the order is built from (address, payment,
  /// shipping, coupon, cart) a new key is minted — the server would
  /// otherwise reject the reused key with 409 IDEMPOTENCY_KEY_MISMATCH.
  String? _idempotencyKey;

  /// [_checkoutFingerprint] of the details [_idempotencyKey] was minted for.
  String? _keyFingerprint;

  String _newIdempotencyKey() {
    final rand = Random.secure();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  @override
  void initState() {
    super.initState();
    // Guest checkout needs no extra session here: a shopper only gets this
    // far with a cart, and adding to the cart already started their
    // anonymous guest cart session. Without one the cart is empty and
    // "Place order" is disabled.
    //
    // Only a signed-in customer's own profile / saved address is prefilled.
    // A guest starts from an EMPTY form and must enter real details.
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

  /// Everything the server builds the order from; a change means a new order.
  String _checkoutFingerprint(ShippingAddress address, String? couponCode) {
    final lines = (ref.read(cartControllerProvider).value?.items ?? const [])
        .map((l) => '${l.productId}/${l.size}x${l.quantity}')
        .join(',');
    return [
      address.toString(),
      _method.apiValue,
      _shippingMethod ?? '',
      couponCode ?? '',
      lines,
    ].join('|');
  }

  /// Same key for an identical retry; a fresh one once the details changed.
  String _keyFor(String fingerprint) {
    if (_idempotencyKey == null || _keyFingerprint != fingerprint) {
      _idempotencyKey = _newIdempotencyKey();
      _keyFingerprint = fingerprint;
    }
    return _idempotencyKey!;
  }

  void _resetIdempotencyKey() {
    _idempotencyKey = null;
    _keyFingerprint = null;
  }

  /// Lands on the order itself so the shopper sees its real payment state.
  /// A guest's order opens through the guest route (in-memory access token).
  void _showPlacedOrder(int orderId, String message) {
    _resetIdempotencyKey(); // order placed: the next submit is a new one
    Haptics.success();
    if (!mounted) return;
    final guest = ref.read(currentUserProvider) == null;
    context.go(
      guest ? Routes.guestOrderPath(orderId) : Routes.orderPath(orderId),
    );
    AppSnackbar.info(context, message);
  }

  /// Clear wording for the checkout-specific 409s; anything else is shown
  /// with the server's own message.
  void _handlePlaceError(AppException e) {
    switch (e.code) {
      case 'IDEMPOTENCY_KEY_MISMATCH':
        // Our key was already used for different details; the next tap
        // starts a genuinely new attempt.
        _resetIdempotencyKey();
        AppSnackbar.error(
          context,
          const AppException(
            'Your checkout details changed since the last attempt. '
            'Please check them and place the order again.',
          ),
        );
      case 'ORDER_ALREADY_PAID':
        _resetIdempotencyKey();
        ref.invalidate(cartControllerProvider);
        if (ref.read(currentUserProvider) == null) {
          AppSnackbar.info(
            context,
            'This order has already been paid — check your email for the '
            'confirmation.',
          );
          context.go(Routes.home);
        } else {
          ref.read(ordersControllerProvider.notifier).refresh().ignore();
          AppSnackbar.info(
            context,
            'This order has already been paid — see it in My orders.',
          );
          context.go(Routes.orders);
        }
      case 'GUEST_SESSION_EXPIRED':
        // The stored guest cart session is gone (and its cart with it).
        _resetIdempotencyKey();
        AppSnackbar.error(
          context,
          const AppException(
            'Your guest cart has expired. Please add your items again.',
          ),
        );
      case 'ORDER_NOT_PENDING':
        _resetIdempotencyKey();
        ref.invalidate(cartControllerProvider);
        AppSnackbar.error(
          context,
          const AppException(
            'That payment attempt was cancelled. Please place the order again.',
          ),
        );
      case 'OUT_OF_STOCK':
        // Refresh so the cart shows which line is over stock.
        ref.invalidate(cartControllerProvider);
        AppSnackbar.error(context, e);
      default:
        AppSnackbar.error(context, e);
    }
  }

  Future<void> _place() async {
    // A second tap while the first request is in flight is ignored (and
    // would reuse the same idempotency key anyway).
    if (_busy) return;
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
    final key = _keyFor(_checkoutFingerprint(address, _couponPreview?.code));
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
          idempotencyKey: key,
        );
        if (!mounted) return;
        // Success is shown ONLY when the API has confirmed the payment
        // (verify/cancel returned paid) — never just because a QR was made.
        if (!await showKhqrPaymentSheet(context, payment)) {
          // The server cancelled that pending order (its key now maps to a
          // cancelled order), so a new attempt needs a new key.
          _resetIdempotencyKey();
          if (mounted) {
            AppSnackbar.info(
              context,
              'Payment not completed. Your items are back in your cart',
            );
          }
          return;
        }
        _showPlacedOrder(
          payment.orderId,
          'Payment received — order #${payment.orderId} placed. Thank you!',
        );
      } else {
        final order = await orders.place(
          paymentMethod: _method,
          address: address,
          couponCode: couponCode,
          shippingMethod: _shippingMethod,
          idempotencyKey: key,
        );
        _showPlacedOrder(
          order.id,
          'Order #${order.id} placed — pay in cash on delivery.',
        );
      }
    } on AppException catch (e) {
      if (mounted) _handlePlaceError(e);
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
    bool phone = false,
    int max = 100,
    TextCapitalization caps = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      textCapitalization: (email || phone) ? TextCapitalization.none : caps,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => _onFieldEdited(),
      validator: (v) =>
          checkoutFieldError(v, email: email, phone: phone, max: max),
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
    final signedIn = ref.watch(currentUserProvider) != null;
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
                _field(_firstName, 'First name', max: 80),
                _field(_lastName, 'Last name', max: 80),
              ),
              const SizedBox(height: 14),
              _field(
                _email,
                'Email',
                type: TextInputType.emailAddress,
                email: true,
                max: 254,
              ),
              const SizedBox(height: 14),
              _field(_street, 'Street address', max: 200),
              const SizedBox(height: 14),
              _pair(_field(_city, 'City'), _field(_state, 'State / province')),
              const SizedBox(height: 14),
              _pair(
                _field(_zip, 'Zip code', type: TextInputType.number, max: 20),
                _field(_country, 'Country'),
              ),
              const SizedBox(height: 14),
              _field(
                _phone,
                'Phone number',
                type: TextInputType.phone,
                phone: true,
                max: 40,
                last: true,
              ),
              const SizedBox(height: 10),
              // Saved addresses belong to an account; a guest has none.
              if (signedIn)
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
              if (signedIn && _saveAddress) ...[
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
