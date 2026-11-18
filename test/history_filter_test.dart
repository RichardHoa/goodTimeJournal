import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/utils/date_presets.dart';
import 'package:mix_app/utils/history_filter.dart';

final _now = DateTime(2026, 11, 18, 10, 30);

FinanceTransaction _moneyIn(
  double amount, {
  String account = 'Cash',
  String? categoryId,
  String note = '',
  DateTime? date,
}) {
  return FinanceTransaction(
    id: 'in-$account-$amount-$categoryId-$note',
    type: TransactionType.moneyIn,
    account: account,
    amount: amount,
    date: date ?? _now,
    note: note,
    categoryId: categoryId,
  );
}

FinanceTransaction _moneyOut(
  double amount, {
  String account = 'Cash',
  String? categoryId,
  String note = '',
  DateTime? date,
}) {
  return FinanceTransaction(
    id: 'out-$account-$amount-$categoryId-$note',
    type: TransactionType.moneyOut,
    account: account,
    amount: amount,
    date: date ?? _now,
    note: note,
    categoryId: categoryId,
  );
}

FinanceTransaction _balanceUpdate(double amount, {String note = '', DateTime? date}) {
  return FinanceTransaction(
    id: 'update-$amount-$note',
    type: TransactionType.fieldUpdate,
    account: 'MB investment',
    amount: amount,
    date: date ?? _now,
    note: note,
    previousValue: 1000,
    newValue: 1000 + amount,
  );
}

void main() {
  group('HistoryFilter', () {
    test('the default filter matches everything and has nothing active', () {
      const filter = HistoryFilter();

      expect(filter.activeCount, 0);
      expect(filter.matches(_moneyIn(100), now: _now), isTrue);
      expect(filter.matches(_moneyOut(30, account: 'VCB', categoryId: 'food'), now: _now), isTrue);
      expect(filter.matches(_balanceUpdate(50), now: _now), isTrue);
      expect(filter.matches(_moneyOut(5, date: DateTime(2001, 1, 1)), now: _now), isTrue);
    });

    group('by type', () {
      test('Money Out only matches Money Out', () {
        const filter = HistoryFilter(types: {HistoryType.moneyOut});

        expect(filter.matches(_moneyOut(30), now: _now), isTrue);
        expect(filter.matches(_moneyIn(100), now: _now), isFalse);
        expect(filter.matches(_balanceUpdate(50), now: _now), isFalse);
      });

      test('Money In and Money Out together match both but not a Balance update', () {
        const filter = HistoryFilter(types: {HistoryType.moneyIn, HistoryType.moneyOut});

        expect(filter.matches(_moneyIn(100), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30), now: _now), isTrue);
        expect(filter.matches(_balanceUpdate(50), now: _now), isFalse);
      });

      test('Balance updates only matches the MB investment balance update', () {
        const filter = HistoryFilter(types: {HistoryType.balanceUpdate});

        expect(filter.matches(_balanceUpdate(50), now: _now), isTrue);
        expect(filter.matches(_moneyIn(100), now: _now), isFalse);
        expect(filter.matches(_moneyOut(30), now: _now), isFalse);
      });
    });

    test('by account it matches records on any of the picked accounts', () {
      const filter = HistoryFilter(accounts: {'Cash', 'MB'});

      expect(filter.matches(_moneyIn(100, account: 'Cash'), now: _now), isTrue);
      expect(filter.matches(_moneyOut(30, account: 'MB'), now: _now), isTrue);
      expect(filter.matches(_moneyOut(30, account: 'VCB'), now: _now), isFalse);
    });

    group('by Category', () {
      test('a Category matches only records in that Category', () {
        const filter = HistoryFilter(categoryIds: {'food'});

        expect(filter.matches(_moneyOut(30, categoryId: 'food'), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, categoryId: 'rent'), now: _now), isFalse);
        expect(filter.matches(_moneyOut(30), now: _now), isFalse);
      });

      test('Uncategorized matches uncategorized Money In and Money Out but not a Balance update', () {
        const filter = HistoryFilter(categoryIds: {null});

        expect(filter.matches(_moneyIn(100), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, categoryId: 'food'), now: _now), isFalse);
        expect(filter.matches(_balanceUpdate(50), now: _now), isFalse);
      });

      test('a Category and Uncategorized together match both kinds', () {
        const filter = HistoryFilter(categoryIds: {'food', null});

        expect(filter.matches(_moneyOut(30, categoryId: 'food'), now: _now), isTrue);
        expect(filter.matches(_moneyIn(100), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, categoryId: 'rent'), now: _now), isFalse);
      });

      test('any Category filter never matches a Balance update', () {
        expect(const HistoryFilter(categoryIds: {'food'}).matches(_balanceUpdate(50), now: _now), isFalse);
        expect(const HistoryFilter(categoryIds: {'food', null}).matches(_balanceUpdate(50), now: _now), isFalse);
      });
    });

    group('by date', () {
      test('This month matches from the 1st at 00:00 to the end of its last day', () {
        const filter = HistoryFilter(datePreset: DatePreset.thisMonth);

        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 11, 1)), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 11, 30, 23, 59)), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 10, 31, 23, 59)), now: _now), isFalse);
      });

      test('a custom range replaces the preset', () {
        final filter = HistoryFilter(
          datePreset: DatePreset.thisMonth,
          customRange: wholeDays(DateTime(2026, 10, 5), DateTime(2026, 10, 10)),
        );

        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 10, 5)), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 10, 10, 23, 59)), now: _now), isTrue);
        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 10, 11)), now: _now), isFalse);
        expect(filter.matches(_moneyOut(30, date: DateTime(2026, 11, 18)), now: _now), isFalse);
      });
    });

    group('by query', () {
      test('matches the note, ignoring case', () {
        const filter = HistoryFilter();
        final lunch = _moneyOut(30, note: 'Lunch with Minh');

        expect(filter.matches(lunch, now: _now, query: 'lunch'), isTrue);
        expect(filter.matches(lunch, now: _now, query: 'MINH'), isTrue);
        expect(filter.matches(lunch, now: _now, query: 'dinner'), isFalse);
      });

      test('matches the account, ignoring case', () {
        const filter = HistoryFilter();

        expect(filter.matches(_moneyOut(30, account: 'Techcombank'), now: _now, query: 'techcom'), isTrue);
        expect(filter.matches(_moneyOut(30, account: 'VCB'), now: _now, query: 'techcom'), isFalse);
      });

      test('matches the amount', () {
        const filter = HistoryFilter();

        expect(filter.matches(_moneyOut(12.5), now: _now, query: '12.5'), isTrue);
        expect(filter.matches(_moneyOut(30), now: _now, query: '12.5'), isFalse);
      });

      test('matches the Category name', () {
        const filter = HistoryFilter();
        const names = {'food': 'Food'};

        expect(
          filter.matches(_moneyOut(30, categoryId: 'food', note: 'noodles'), now: _now, query: 'foo', categoryNames: names),
          isTrue,
        );
        expect(
          filter.matches(_moneyOut(30, categoryId: 'rent', note: 'noodles'), now: _now, query: 'foo', categoryNames: names),
          isFalse,
        );
      });

      test('must match as well as the other fields', () {
        const filter = HistoryFilter(accounts: {'Cash'});

        expect(filter.matches(_moneyOut(30, account: 'Cash', note: 'Coffee'), now: _now, query: 'coffee'), isTrue);
        expect(filter.matches(_moneyOut(30, account: 'VCB', note: 'Coffee'), now: _now, query: 'coffee'), isFalse);
        expect(filter.matches(_moneyOut(30, account: 'Cash', note: 'Tea'), now: _now, query: 'coffee'), isFalse);
      });
    });

    group('activeCount', () {
      test('counts each narrowed field once', () {
        expect(const HistoryFilter(types: {HistoryType.moneyIn, HistoryType.moneyOut}).activeCount, 1);
        expect(const HistoryFilter(accounts: {'Cash', 'MB'}).activeCount, 1);
        expect(const HistoryFilter(categoryIds: {'food', null}).activeCount, 1);
        expect(const HistoryFilter(datePreset: DatePreset.today).activeCount, 1);
        expect(
          const HistoryFilter(
            types: {HistoryType.moneyOut},
            accounts: {'Cash'},
            datePreset: DatePreset.thisWeek,
          ).activeCount,
          3,
        );
      });

      test('a custom range counts as the date', () {
        final filter = HistoryFilter(customRange: wholeDays(DateTime(2026, 10, 5), DateTime(2026, 10, 10)));

        expect(filter.activeCount, 1);
      });

      test('All time does not count', () {
        const filter = HistoryFilter(
          types: {HistoryType.moneyOut},
          accounts: {'Cash'},
          categoryIds: {'food'},
          datePreset: DatePreset.allTime,
        );

        expect(filter.activeCount, 3);
      });
    });

    group('rangeFor', () {
      test('is null for All time with no custom range', () {
        expect(const HistoryFilter().rangeFor(_now), isNull);
      });

      test('is the preset range as of now', () {
        final range = const HistoryFilter(datePreset: DatePreset.thisMonth).rangeFor(_now)!;

        expect(range.start, DateTime(2026, 11, 1));
        expect(range.end, DateTime(2026, 11, 30, 23, 59, 59, 999));
      });

      test('is the custom range when one is set', () {
        final filter = HistoryFilter(
          datePreset: DatePreset.thisMonth,
          customRange: wholeDays(DateTime(2026, 10, 5), DateTime(2026, 10, 10)),
        );

        final range = filter.rangeFor(_now)!;
        expect(range.start, DateTime(2026, 10, 5));
        expect(range.end, DateTime(2026, 10, 10, 23, 59, 59, 999));
      });
    });
  });

  group('HistorySummary', () {
    test('sums Money In and Money Out, and net is in minus out', () {
      final summary = HistorySummary.of([
        _moneyIn(100),
        _moneyIn(50.5),
        _moneyOut(30),
        _moneyOut(20.25),
      ]);

      expect(summary.moneyIn, 150.5);
      expect(summary.moneyOut, 50.25);
      expect(summary.net, 100.25);
    });

    test('Balance updates count toward nothing', () {
      final summary = HistorySummary.of([
        _moneyIn(100),
        _balanceUpdate(500),
        _moneyOut(30),
      ]);

      expect(summary.moneyIn, 100);
      expect(summary.moneyOut, 30);
      expect(summary.net, 70);
      expect(summary.moneyInByCategory, {null: 100});
      expect(summary.moneyOutByCategory, {null: 30});
    });

    test('breaks each direction down by its own Categories', () {
      final summary = HistorySummary.of([
        _moneyOut(30, categoryId: 'food'),
        _moneyOut(10, categoryId: 'food'),
        _moneyOut(20.25),
        _moneyIn(100, categoryId: 'salary'),
        _moneyIn(50.5),
      ]);

      expect(summary.moneyOutByCategory, {'food': 40, null: 20.25});
      expect(summary.moneyInByCategory, {'salary': 100, null: 50.5});
      expect(summary.moneyInByCategory.containsKey('food'), isFalse);
      expect(summary.moneyOutByCategory.containsKey('salary'), isFalse);
    });

    test('no records sums to zero', () {
      final summary = HistorySummary.of([]);

      expect(summary.moneyIn, 0);
      expect(summary.moneyOut, 0);
      expect(summary.net, 0);
      expect(summary.moneyInByCategory, isEmpty);
      expect(summary.moneyOutByCategory, isEmpty);
    });

    test('sums amounts without floating-point noise', () {
      final summary = HistorySummary.of([
        _moneyOut(0.1, categoryId: 'food'),
        _moneyOut(0.2, categoryId: 'food'),
      ]);

      expect(summary.moneyOut, 0.3);
      expect(summary.moneyOutByCategory, {'food': 0.3});
      expect(summary.net, -0.3);
    });
  });
}
