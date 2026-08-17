import 'package:flutter/material.dart';

/// Quick date ranges for filtering history. All ranges cover whole days.
enum DatePreset {
  allTime('All time'),
  today('Today'),
  thisWeek('This week'),
  thisMonth('This month');

  final String label;
  const DatePreset(this.label);

  /// The range this preset covers as of [now]; null for All time.
  DateTimeRange? rangeFor(DateTime now) {
    switch (this) {
      case DatePreset.allTime:
        return null;
      case DatePreset.today:
        return wholeDays(now, now);
      case DatePreset.thisWeek:
        // Weeks start on Monday (weekday 1).
        final monday = DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));
        return wholeDays(monday, now);
      case DatePreset.thisMonth:
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return wholeDays(DateTime(now.year, now.month, 1), lastDay);
    }
  }
}

/// From 00:00 on [first]'s day to the last millisecond of [last]'s day.
DateTimeRange wholeDays(DateTime first, DateTime last) {
  return DateTimeRange(
    start: DateTime(first.year, first.month, first.day),
    end: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
  );
}
