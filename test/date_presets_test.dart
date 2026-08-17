import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/utils/date_presets.dart';

void main() {
  group('This week', () {
    test('on a Monday it starts that Monday at 00:00', () {
      final range = DatePreset.thisWeek.rangeFor(DateTime(2026, 9, 28, 15, 20))!;

      expect(range.start, DateTime(2026, 9, 28));
      expect(range.end, DateTime(2026, 9, 28, 23, 59, 59, 999));
    });

    test('mid-week it starts the previous Monday and ends today', () {
      final range = DatePreset.thisWeek.rangeFor(DateTime(2026, 10, 1, 9))!;

      expect(range.start, DateTime(2026, 9, 28));
      expect(range.end, DateTime(2026, 10, 1, 23, 59, 59, 999));
    });

    test('on a Sunday it starts six days earlier', () {
      final range = DatePreset.thisWeek.rangeFor(DateTime(2026, 10, 4, 23, 59))!;

      expect(range.start, DateTime(2026, 9, 28));
      expect(range.end, DateTime(2026, 10, 4, 23, 59, 59, 999));
    });
  });

  test('This month runs from the 1st to the end of its last day', () {
    final range = DatePreset.thisMonth.rangeFor(DateTime(2026, 2, 14, 8))!;

    expect(range.start, DateTime(2026, 2, 1));
    expect(range.end, DateTime(2026, 2, 28, 23, 59, 59, 999));

    final december = DatePreset.thisMonth.rangeFor(DateTime(2026, 12, 31, 23))!;
    expect(december.start, DateTime(2026, 12, 1));
    expect(december.end, DateTime(2026, 12, 31, 23, 59, 59, 999));
  });

  test('Today covers the whole of today', () {
    final range = DatePreset.today.rangeFor(DateTime(2026, 9, 1, 10, 30))!;

    expect(range.start, DateTime(2026, 9, 1));
    expect(range.end, DateTime(2026, 9, 1, 23, 59, 59, 999));
  });

  test('All time has no range', () {
    expect(DatePreset.allTime.rangeFor(DateTime(2026, 9, 1)), isNull);
  });

  test('a picked range covers whole days at both ends', () {
    final range = wholeDays(DateTime(2026, 9, 3, 14), DateTime(2026, 9, 10));

    expect(range.start, DateTime(2026, 9, 3));
    expect(range.end, DateTime(2026, 9, 10, 23, 59, 59, 999));
  });
}
