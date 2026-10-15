import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/network_providers.dart';
import 'admin_ui.dart';

class CouponFormScreen extends ConsumerStatefulWidget {
  const CouponFormScreen({super.key, this.coupon});

  final Map<String, dynamic>? coupon;

  @override
  ConsumerState<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends ConsumerState<CouponFormScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  String _type = 'PERCENT';
  bool _active = true;
  DateTime? _starts;
  DateTime? _expires;
  bool _busy = false;
  String? _error;

  TextEditingController _field(String key) => _fields.putIfAbsent(key, () {
    final value = widget.coupon?[key];
    return TextEditingController(text: value == null ? '' : '$value');
  });

  @override
  void initState() {
    super.initState();
    _type = '${widget.coupon?['discountType'] ?? 'PERCENT'}';
    _active = widget.coupon?['active'] != false;
    _starts = DateTime.tryParse(
      '${widget.coupon?['startsAt'] ?? ''}',
    )?.toLocal();
    _expires = DateTime.tryParse(
      '${widget.coupon?['expiresAt'] ?? ''}',
    )?.toLocal();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final current = start ? _starts : _expires;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => start ? _starts = picked : _expires = picked);
    }
  }

  String? _number(String key, {bool whole = false, double? min, double? max}) {
    final value = _field(key).text.trim();
    if (value.isEmpty) return null;
    final number = whole ? int.tryParse(value) : double.tryParse(value);
    if (number == null ||
        (min != null && number < min) ||
        (max != null && number > max)) {
      return 'Enter ${whole ? 'a whole number' : 'a number'}${min == null ? '' : ' of at least $min'}${max == null ? '' : ' up to $max'}';
    }
    return null;
  }

  dynamic _value(String key, {bool whole = false}) {
    final value = _field(key).text.trim();
    if (value.isEmpty) return null;
    return whole ? int.parse(value) : double.parse(value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_starts != null && _expires != null && _expires!.isBefore(_starts!)) {
      setState(() => _error = 'Expiry must be on or after the start date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'code': _field('code').text.trim().toUpperCase(),
      'description': _field('description').text.trim(),
      'discountType': _type,
      'percentOff': _type == 'PERCENT'
          ? _value('percentOff', whole: true)
          : null,
      'amountOff': _type == 'FIXED' ? _value('amountOff') : null,
      'maxDiscount': _type == 'PERCENT' ? _value('maxDiscount') : null,
      'minSubtotal': _value('minSubtotal') ?? 0,
      'usageLimit': _value('usageLimit', whole: true),
      'perCustomerLimit': _value('perCustomerLimit', whole: true),
      'startsAt': _starts == null
          ? null
          : DateTime(
              _starts!.year,
              _starts!.month,
              _starts!.day,
            ).toUtc().toIso8601String(),
      'expiresAt': _expires == null
          ? null
          : DateTime(
              _expires!.year,
              _expires!.month,
              _expires!.day,
              23,
              59,
              59,
            ).toUtc().toIso8601String(),
      'active': _active,
    };
    try {
      final dio = ref.read(dioProvider);
      if (widget.coupon == null) {
        await dio.post('/api/admin/coupons', data: body);
      } else {
        await dio.put('/api/admin/coupons/${widget.coupon!['id']}', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (mounted) {
        setState(
          () => _error = body is Map && body['message'] != null
              ? '${body['message']}'
              : e.message ?? 'Could not save coupon',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _input(
    String key,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _field(key),
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.coupon == null ? 'Add coupon' : 'Edit coupon'),
      backgroundColor: AppColors.surface,
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const AdminSectionHeading('Coupon details'),
          _input(
            'code',
            'Code',
            maxLength: 30,
            validator: (v) =>
                RegExp(r'^[A-Za-z0-9_-]{1,30}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Use letters, digits, - or _',
          ),
          _input('description', 'Description', maxLength: 200),
          const AdminSectionHeading('Discount'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Discount type'),
            items: const [
              DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
              DropdownMenuItem(value: 'FIXED', child: Text('Fixed amount')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'PERCENT'),
          ),
          const SizedBox(height: 12),
          if (_type == 'PERCENT') ...[
            _input(
              'percentOff',
              'Percent off (1–90)',
              keyboardType: TextInputType.number,
              validator: (_) => _field('percentOff').text.trim().isEmpty
                  ? 'Required'
                  : _number('percentOff', whole: true, min: 1, max: 90),
            ),
            _input(
              'maxDiscount',
              'Maximum discount (optional)',
              keyboardType: TextInputType.number,
              validator: (_) => _number('maxDiscount', min: 0.01),
            ),
          ] else
            _input(
              'amountOff',
              'Amount off',
              keyboardType: TextInputType.number,
              validator: (_) => _field('amountOff').text.trim().isEmpty
                  ? 'Required'
                  : _number('amountOff', min: 0.01),
            ),
          _input(
            'minSubtotal',
            'Minimum subtotal (optional)',
            keyboardType: TextInputType.number,
            validator: (_) => _number('minSubtotal', min: 0),
          ),
          const AdminSectionHeading('Availability'),
          _input(
            'usageLimit',
            'Total uses (optional)',
            keyboardType: TextInputType.number,
            validator: (_) => _number('usageLimit', whole: true, min: 1),
          ),
          _input(
            'perCustomerLimit',
            'Uses per customer (optional)',
            keyboardType: TextInputType.number,
            validator: (_) => _number('perCustomerLimit', whole: true, min: 1),
          ),
          ListTile(
            title: Text(
              'Starts: ${_starts == null ? 'Immediately' : '${_starts!.year}-${_starts!.month}-${_starts!.day}'}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _date(true),
          ),
          if (_starts != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _starts = null),
                child: const Text('Clear start date'),
              ),
            ),
          ListTile(
            title: Text(
              'Expires: ${_expires == null ? 'Never' : '${_expires!.year}-${_expires!.month}-${_expires!.day}'}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _date(false),
          ),
          if (_expires != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expires = null),
                child: const Text('Clear expiry'),
              ),
            ),
          AdminSurface(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Customers can apply this coupon'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ),
          if (_error != null)
            AdminSurface(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_busy ? 'Saving coupon…' : 'Save coupon'),
        ),
      ),
    ),
  );
}
