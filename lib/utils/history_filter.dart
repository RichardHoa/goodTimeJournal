import 'package:flutter/material.dart';
import '../models/finance_model.dart';
import 'amounts.dart';
import 'date_presets.dart';

/// Kinds of record the history can be narrowed to.
enum HistoryType {
  moneyIn('Money In'),
  moneyOut('Money Out'),
  balanceUpdate('Balance updates');

  final String label;
  const HistoryType(this.label);
}

/// What the transaction history shows. An empty set means no narrowing on
/// that field.
class HistoryFilter {
  final Set<HistoryType> types;
  final Set<String> accounts;
  /// Category ids; `null` in the set stands for Uncategorized. When not
  /// empty, only Money In and Money Out records can match.
  final Set<String?> categoryIds;
  final DatePreset datePreset;
  /// A picked range of whole days; when set it replaces [datePreset].
  final DateTimeRange? customRange;

  const HistoryFilter({
    this.types = const {},
    this.accounts = const {},
    this.categoryIds = const {},
    this.datePreset = DatePreset.allTime,
    this.customRange,
  });

  /// How many of type, account, category and date narrow the history.
  int get activeCount {
    final hasDate = customRange != null || datePreset != DatePreset.allTime;
    return [types.isNotEmpty, accounts.isNotEmpty, categoryIds.isNotEmpty, hasDate].where((on) => on).length;
  }

  /// The date range in effect as of [now]; null for all time.
  DateTimeRange? rangeFor(DateTime now) => customRange ?? datePreset.rangeFor(now);

  /// Whether [t] passes this filter and matches [query] (case-insensitive,
  /// against its note, account, amount or Category name), as of [now].
  /// [categoryNames] maps Category ids to names.
  bool matches(
    FinanceTransaction t, {
    required DateTime now,
    String query = '',
    Map<String, String> categoryNames = const {},
  }) {
    final type = switch (t.type) {
      TransactionType.moneyIn => HistoryType.moneyIn,
      TransactionType.moneyOut => HistoryType.moneyOut,
      TransactionType.fieldUpdate => HistoryType.balanceUpdate,
    };
    if (types.isNotEmpty && !types.contains(type)) return false;
    if (accounts.isNotEmpty && !accounts.contains(t.account)) return false;
    if (categoryIds.isNotEmpty) {
      if (type == HistoryType.balanceUpdate || !categoryIds.contains(t.categoryId)) return false;
    }

    final range = rangeFor(now);
    if (range != null && (t.date.isBefore(range.start) || t.date.isAfter(range.end))) return false;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final categoryName = categoryNames[t.categoryId]?.toLowerCase() ?? '';
    return t.note.toLowerCase().contains(q) ||
        t.account.toLowerCase().contains(q) ||
        t.amount.toString().contains(q) ||
        formatAmountK(t.amount).contains(q) ||
        categoryName.contains(q);
  }

  HistoryFilter copyWith({
    Set<HistoryType>? types,
    Set<String>? accounts,
    Set<String?>? categoryIds,
    DatePreset? datePreset,
    DateTimeRange? Function()? customRange,
  }) {
    return HistoryFilter(
      types: types ?? this.types,
      accounts: accounts ?? this.accounts,
      categoryIds: categoryIds ?? this.categoryIds,
      datePreset: datePreset ?? this.datePreset,
      customRange: customRange != null ? customRange() : this.customRange,
    );
  }
}

/// Totals for a set of records. Balance updates count toward nothing.
class HistorySummary {
  final double moneyIn;
  final double moneyOut;
  /// Money In by Category id (null: Uncategorized).
  final Map<String?, double> moneyInByCategory;
  /// Money Out by Category id (null: Uncategorized).
  final Map<String?, double> moneyOutByCategory;

  const HistorySummary({
    required this.moneyIn,
    required this.moneyOut,
    required this.moneyInByCategory,
    required this.moneyOutByCategory,
  });

  /// Money In minus Money Out.
  double get net => roundAmount(moneyIn - moneyOut);

  factory HistorySummary.of(Iterable<FinanceTransaction> transactions) {
    var moneyIn = 0.0;
    var moneyOut = 0.0;
    final inByCategory = <String?, double>{};
    final outByCategory = <String?, double>{};
    for (final t in transactions) {
      switch (t.type) {
        case TransactionType.moneyIn:
          moneyIn += t.amount;
          inByCategory[t.categoryId] = roundAmount((inByCategory[t.categoryId] ?? 0) + t.amount);
        case TransactionType.moneyOut:
          moneyOut += t.amount;
          outByCategory[t.categoryId] = roundAmount((outByCategory[t.categoryId] ?? 0) + t.amount);
        case TransactionType.fieldUpdate:
          break;
      }
    }
    return HistorySummary(
      moneyIn: roundAmount(moneyIn),
      moneyOut: roundAmount(moneyOut),
      moneyInByCategory: inByCategory,
      moneyOutByCategory: outByCategory,
    );
  }
}
