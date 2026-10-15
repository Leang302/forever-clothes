import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization capitalization;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.capitalization,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: widget.label,
        prefixIcon: Icon(widget.icon, color: AppColors.muted, size: 22),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                  size: 22,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

abstract final class Validators {
  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
        ? null
        : 'Enter a valid email';
  }

  static String? newPassword(String? v) =>
      (v == null || v.length < 8) ? 'Use at least 8 characters' : null;
}
