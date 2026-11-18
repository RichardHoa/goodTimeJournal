import 'package:intl/intl.dart';

/// The most decimal places an amount in k can have.
const int amountDecimals = 5;

final NumberFormat _vndFormatter = NumberFormat('#,##0.##', 'en_US');
final RegExp _number = RegExp(r'^\d+(\.\d+)?$');

/// [k] rounded half away from zero to [amountDecimals] places. The nudge
/// makes a typed half like `1.234565`, stored as 1.2345649999…, round up.
double roundAmount(double k) {
  final scaled = k * 100000;
  return (scaled + (scaled >= 0 ? 1e-6 : -1e-6)).round() / 100000;
}

/// Evaluates an amount typed in k: a number, or a sum like `30+50*2` using
/// `+ - * /` (`×` and `÷` too), with `*` and `/` before `+` and `-`. A `,`
/// is read as a decimal point. Null when the text isn't a valid expression,
/// a number has more than [amountDecimals] decimals, or it divides by zero.
/// The result is rounded to [amountDecimals] places.
double? evaluateAmount(String text) {
  final normalized = text.replaceAll(',', '.').replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
  if (normalized.isEmpty) return null;

  // Split into alternating numbers and operators; a leading minus belongs
  // to the first number.
  final numbers = <double>[];
  final operators = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < normalized.length; i++) {
    final c = normalized[i];
    final isOperator = '+-*/'.contains(c) && !(c == '-' && i == 0);
    if (!isOperator) {
      current.write(c);
      continue;
    }
    final value = _parseNumber(current.toString());
    if (value == null) return null;
    numbers.add(value);
    operators.add(c);
    current.clear();
  }
  final last = _parseNumber(current.toString());
  if (last == null) return null;
  numbers.add(last);

  // `*` and `/` first, folding into the running term; then `+` and `-`.
  final terms = <double>[numbers.first];
  final signs = <String>[];
  for (var i = 0; i < operators.length; i++) {
    final next = numbers[i + 1];
    switch (operators[i]) {
      case '*':
        terms.last = terms.last * next;
      case '/':
        if (next == 0) return null;
        terms.last = terms.last / next;
      default:
        signs.add(operators[i]);
        terms.add(next);
    }
  }
  var result = terms.first;
  for (var i = 0; i < signs.length; i++) {
    result = signs[i] == '+' ? result + terms[i + 1] : result - terms[i + 1];
  }
  return roundAmount(result);
}

/// A number with at most [amountDecimals] decimals, optionally negative.
double? _parseNumber(String text) {
  final digits = text.startsWith('-') ? text.substring(1) : text;
  if (!_number.hasMatch(digits)) return null;
  final dot = digits.indexOf('.');
  if (dot != -1 && digits.length - dot - 1 > amountDecimals) return null;
  return double.parse(text);
}

/// Whether [text] uses an operator, so is worth showing a result hint for.
bool isAmountExpression(String text) {
  final trimmed = text.trim();
  final body = trimmed.startsWith('-') ? trimmed.substring(1) : trimmed;
  return RegExp(r'[+\-*/×÷]').hasMatch(body);
}

/// [k] as typed in an amount field: up to [amountDecimals] decimals, no
/// trailing zeros and no grouping, e.g. `12.5`, `80`, `0.00001`.
String formatAmountK(double k) {
  final fixed = roundAmount(k).toStringAsFixed(amountDecimals);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// [k] in full đồng with grouping and up to 2 decimals (5 decimals in k),
/// none when whole, e.g. `12,345.67 VND`, `80,000 VND`.
String formatVnd(double k) => '${_vndFormatter.format(roundAmount(k) * 1000)} VND';
