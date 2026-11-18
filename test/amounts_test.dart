import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/utils/amounts.dart';

void main() {
  group('evaluateAmount', () {
    test('reads a plain number', () {
      expect(evaluateAmount('80'), 80);
    });

    test('ignores surrounding spaces', () {
      expect(evaluateAmount(' 12.5 '), closeTo(12.5, 1e-9));
    });

    test('reads a comma as a decimal point', () {
      expect(evaluateAmount('12,5'), closeTo(12.5, 1e-9));
    });

    test('adds two numbers', () {
      expect(evaluateAmount('30+50'), 80);
    });

    test('allows spaces around operators', () {
      expect(evaluateAmount('30 + 50'), 80);
    });

    test('multiplies before adding', () {
      expect(evaluateAmount('10+5*2'), 20);
    });

    test('divides before subtracting', () {
      expect(evaluateAmount('100-20/4'), 95);
    });

    test('treats × and ÷ like * and /', () {
      expect(evaluateAmount('10+5×2'), 20);
      expect(evaluateAmount('100-20÷4'), 95);
    });

    test('evaluates a chain left to right', () {
      expect(evaluateAmount('1+2+3-4'), 2);
    });

    test('divides into a fraction', () {
      expect(evaluateAmount('10/4'), closeTo(2.5, 1e-9));
    });

    test('accepts numbers with five decimals', () {
      expect(evaluateAmount('0.00001'), closeTo(0.00001, 1e-9));
      expect(evaluateAmount('12.34567'), closeTo(12.34567, 1e-9));
    });

    test('rejects a number with six decimals', () {
      expect(evaluateAmount('0.000001'), isNull);
      expect(evaluateAmount('12.345678'), isNull);
    });

    test('rounds the result to five decimals', () {
      expect(evaluateAmount('10/3'), closeTo(3.33333, 1e-9));
      expect(evaluateAmount('2/3'), closeTo(0.66667, 1e-9));
    });

    test('evaluates a leading minus to a negative number', () {
      expect(evaluateAmount('-5'), -5);
    });

    test('can go negative when subtracting more than there is', () {
      expect(evaluateAmount('5-10'), -5);
    });

    test('is null for an empty string', () {
      expect(evaluateAmount(''), isNull);
    });

    test('is null for text', () {
      expect(evaluateAmount('abc'), isNull);
    });

    test('is null for a trailing operator', () {
      expect(evaluateAmount('30+'), isNull);
    });

    test('is null for a lone operator', () {
      expect(evaluateAmount('+'), isNull);
    });

    test('is null for doubled operators', () {
      expect(evaluateAmount('30++50'), isNull);
    });

    test('is null when dividing by zero', () {
      expect(evaluateAmount('5/0'), isNull);
    });

    test('is null for a number with two decimal points', () {
      expect(evaluateAmount('1.2.3'), isNull);
    });
  });

  group('isAmountExpression', () {
    test('is true when the text uses an operator', () {
      expect(isAmountExpression('30+50'), isTrue);
      expect(isAmountExpression('5*2'), isTrue);
      expect(isAmountExpression('10÷2'), isTrue);
    });

    test('is false for a plain number', () {
      expect(isAmountExpression('80'), isFalse);
      expect(isAmountExpression('12.5'), isFalse);
      expect(isAmountExpression('12,5'), isFalse);
    });

    test('is false for an empty string', () {
      expect(isAmountExpression(''), isFalse);
    });

    test('is false for a lone leading minus', () {
      expect(isAmountExpression('-5'), isFalse);
    });
  });

  group('roundAmount', () {
    test('removes floating-point noise', () {
      expect(roundAmount(0.1 + 0.2), 0.3);
    });

    test('rounds half up at the fifth decimal', () {
      expect(roundAmount(1.234565), closeTo(1.23457, 1e-9));
    });

    test('leaves a whole number unchanged', () {
      expect(roundAmount(3), 3);
    });
  });

  group('formatAmountK', () {
    test('shows a whole number without decimals', () {
      expect(formatAmountK(80), '80');
    });

    test('drops trailing zeros', () {
      expect(formatAmountK(12.5), '12.5');
    });

    test('shows up to five decimals', () {
      expect(formatAmountK(0.00001), '0.00001');
      expect(formatAmountK(12.34567), '12.34567');
    });

    test('does not group thousands', () {
      expect(formatAmountK(1234.5), '1234.5');
    });

    test('hides floating-point noise', () {
      expect(formatAmountK(0.1 + 0.2), '0.3');
    });
  });

  group('formatVnd', () {
    test('shows a whole amount in grouped đồng', () {
      expect(formatVnd(80), '80,000 VND');
    });

    test('shows up to two decimals of đồng', () {
      expect(formatVnd(12.34567), '12,345.67 VND');
    });

    test('shows a fraction of a k as whole đồng', () {
      expect(formatVnd(0.5), '500 VND');
    });

    test('groups millions', () {
      expect(formatVnd(1234.5), '1,234,500 VND');
    });

    test('shows zero', () {
      expect(formatVnd(0), '0 VND');
    });

    test('puts the minus sign before a negative amount', () {
      expect(formatVnd(-12.5), '-12,500 VND');
    });
  });
}
