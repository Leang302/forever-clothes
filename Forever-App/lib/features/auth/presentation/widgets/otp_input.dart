import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';

/// Six boxes for the e-mailed one-time code, backed by one invisible text field so the OS keyboard,
/// paste and SMS/e-mail autofill (`oneTimeCode`) all keep working.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.onCompleted,
    this.length = 6,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final int length;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();
  String _last = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text;
    if (text == _last) return;
    _last = text;
    setState(() {});
    if (text.length == widget.length) widget.onCompleted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final activeIndex = text.length.clamp(0, widget.length - 1);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Box(
                  character: i < text.length ? text[i] : '',
                  active: _focus.hasFocus && i == activeIndex,
                  filled: i < text.length,
                ),
              ],
            ],
          ),
          // Invisible but focusable input that receives the typing.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.character,
    required this.active,
    required this.filled,
  });

  final String character;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 50,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.fill : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.ink : AppColors.line,
          width: active ? 1.8 : 1,
        ),
      ),
      child: Text(
        character,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
