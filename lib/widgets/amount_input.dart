import 'package:flutter/material.dart';
import '../utils/amounts.dart';

/// Parse an amount typed in k: a number or a sum like `30+50` (accepts `,`
/// as the decimal separator).
double? parseAmountK(String text) => evaluateAmount(text);

/// The hint below an amount typed in k: the full-VND value, e.g.
/// `= 50,000 VND`, plus the result for a sum, e.g. `= 80 k · 80,000 VND`.
/// Null when the text isn't a positive amount.
String? vndPreview(String text) {
  final parsed = parseAmountK(text);
  if (parsed == null || parsed <= 0) return null;
  if (isAmountExpression(text)) return '= ${formatAmountK(parsed)} k · ${formatVnd(parsed)}';
  return '= ${formatVnd(parsed)}';
}

/// Problem with an amount typed in k, or null when it can be saved.
/// [allowZero] accepts 0, e.g. for a balance or a Fund.
String? validateAmountText(String? text, {bool allowZero = false}) {
  if (text == null || text.trim().isEmpty) return 'Please enter an amount';
  final parsed = parseAmountK(text);
  if (parsed == null) return 'Not a valid amount (up to $amountDecimals decimals, e.g. 50 or 30+20)';
  if (parsed < 0 || (!allowZero && parsed == 0)) return 'Please enter a positive amount';
  return null;
}

/// An amount field in k: `đ` before, `k` after, a row of `+ − × ÷` keys
/// (number keyboards lack them), and the result below. Tapping the result
/// of a sum replaces the text with it; saving uses the result either way.
class AmountField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  /// Shown when given, for fields outside a [Form].
  final String? errorText;
  /// For fields inside a [Form].
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AmountField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.errorText,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  /// Rebuild so the hint follows the typed amount.
  void _rebuild() => setState(() {});

  void _setText(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
  }

  /// Insert [op] at the cursor (or the end).
  void _insertOperator(String op) {
    final value = widget.controller.value;
    final text = value.text;
    final at = value.selection.isValid ? value.selection.start : text.length;
    final end = value.selection.isValid ? value.selection.end : text.length;
    final next = text.replaceRange(at, end, op);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + op.length),
    );
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final affixStyle = TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 16);
    final text = widget.controller.text;
    final preview = vndPreview(text);
    final result = isAmountExpression(text) ? parseAmountK(text) : null;
    final canUseResult = result != null && result > 0;

    // Icon slots rather than prefixText/suffixText, which hide while the
    // field is empty and unfocused.
    final decoration = InputDecoration(
      prefixIcon: Center(widthFactor: 1, heightFactor: 1, child: Text('đ', style: affixStyle)),
      prefixIconConstraints: const BoxConstraints(minWidth: 44),
      suffixIcon: Center(widthFactor: 1, heightFactor: 1, child: Text('k', style: affixStyle)),
      suffixIconConstraints: const BoxConstraints(minWidth: 40),
      helper: preview == null
          ? null
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canUseResult ? () => _setText(formatAmountK(result)) : null,
              child: Row(
                children: [
                  Flexible(
                    child: Text(preview, style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ),
                  if (canUseResult) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_outline_rounded, size: 15, color: primary),
                    const SizedBox(width: 2),
                    Text('Use', style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
      errorText: widget.errorText,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          validator: widget.validator,
          decoration: decoration,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (label, op) in const [('+', '+'), ('−', '-'), ('×', '*'), ('÷', '/')]) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _insertOperator(op),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: Text(label),
                ),
              ),
              if (op != '/') const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}
