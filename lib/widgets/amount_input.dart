import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _vndFormatter = NumberFormat('#,###', 'en_US');

/// Parse an amount typed in k (accepts `,` as the decimal separator).
double? parseAmountK(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// The full-VND preview for an amount typed in k, e.g. `= 50,000 VND`, or
/// null when the text isn't a positive number.
String? vndPreview(String text) {
  final parsed = parseAmountK(text);
  if (parsed == null || parsed <= 0) return null;
  return '= ${_vndFormatter.format(parsed * 1000)} VND';
}

/// Decoration for every amount field: `đ` before, `k` after, and the
/// full-VND preview below.
InputDecoration amountInputDecoration(
  BuildContext context, {
  required String text,
  String? errorText,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  final affixStyle = TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 16);
  // Icon slots rather than prefixText/suffixText, which hide while the
  // field is empty and unfocused.
  return InputDecoration(
    prefixIcon: Center(widthFactor: 1, heightFactor: 1, child: Text('đ', style: affixStyle)),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    suffixIcon: Center(widthFactor: 1, heightFactor: 1, child: Text('k', style: affixStyle)),
    suffixIconConstraints: const BoxConstraints(minWidth: 40),
    helperText: vndPreview(text),
    helperStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
    errorText: errorText,
  );
}
