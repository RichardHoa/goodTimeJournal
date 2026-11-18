import '../models/finance_model.dart';

/// Finance data read from a CSV export.
class FinanceImport {
  final AccountBalances balances;
  final List<FinanceTransaction> transactions;
  final List<Fund> funds;
  final List<Category> categories;

  const FinanceImport({
    required this.balances,
    required this.transactions,
    required this.funds,
    this.categories = const [],
  });
}

/// The finance CSV format: an account balances summary (with one row per
/// Fund), the Categories, then a transactions log. Pure text in and out.
class FinanceCsv {
  static const String _summaryMarker = '--- ACCOUNT BALANCES SUMMARY ---';
  static const String _transactionsMarker = '--- TRANSACTIONS LOG ---';
  static const String _categoriesMarker = '--- CATEGORIES ---';
  static const String _fundPrefix = 'Fund: ';

  /// Exports finance balances, Funds and transactions to CSV. Trash is
  /// never passed in, so it is never exported.
  static String encode(
    AccountBalances balances,
    List<FinanceTransaction> transactions,
    List<Fund> funds, {
    List<Category> categories = const [],
  }) {
    final buffer = StringBuffer();
    void amountRow(String label, double k) {
      buffer.writeln('${_escapeCsvField(label)},$k,${(k * 1000).round()}');
    }

    buffer.writeln(_summaryMarker);
    buffer.writeln('Account,Amount (k VND),Amount (VND)');
    balances.toAccounts().forEach(amountRow);
    amountRow('Total Money', balances.totalMoney);
    for (final fund in funds) {
      amountRow('$_fundPrefix${fund.name}', fund.amount);
    }
    final fundsTotal = funds.fold(0.0, (sum, f) => sum + f.amount);
    amountRow('Funds total', fundsTotal);
    amountRow('Money Left', balances.totalMoney - fundsTotal);
    buffer.writeln();

    buffer.writeln(_categoriesMarker);
    buffer.writeln('type,name');
    for (final c in categories) {
      buffer.writeln('${c.type.name},${_escapeCsvField(c.name)}');
    }
    buffer.writeln();

    buffer.writeln(_transactionsMarker);
    final categoryNames = {for (final c in categories) c.id: c.name};
    buffer.writeln(_Column.values.map((c) => c.header).join(','));
    for (final t in transactions) {
      buffer.writeln(_Column.values.map((c) => c.write(t, categoryNames)).join(','));
    }

    return buffer.toString();
  }

  /// Reads a CSV written by [encode]. Every transaction, Fund and Category
  /// gets an id from [newId], and every Fund and Category gets [now] as its
  /// creation time, in the file's order. Exports made before the `datetime`
  /// column existed still import: their transactions get the start of their
  /// day as the time. Exports made before Categories import with none.
  /// Throws a [FormatException] if the text isn't a finance export.
  static FinanceImport decode(String csv, {required String Function() newId, required DateTime now}) {
    final text = csv.startsWith('﻿') ? csv.substring(1) : csv;
    final rows = _parseCsvRows(text).where((r) => r.any((field) => field.trim().isNotEmpty)).toList();

    final summaryStart = rows.indexWhere((r) => r.first.trim() == _summaryMarker);
    final transactionsStart = rows.indexWhere((r) => r.first.trim() == _transactionsMarker);
    if (summaryStart == -1 || transactionsStart == -1 || transactionsStart < summaryStart) {
      throw const FormatException('Not a mixApp finance export');
    }

    final categoriesStart = rows.indexWhere((r) => r.first.trim() == _categoriesMarker);
    final hasCategories = categoriesStart > summaryStart && categoriesStart < transactionsStart;
    final summaryEnd = hasCategories ? categoriesStart : transactionsStart;

    final categories = <Category>[];
    if (hasCategories) {
      // Skip the marker and the header row.
      for (final row in rows.sublist(categoriesStart + 2, transactionsStart)) {
        final type = TransactionType.values.asNameMap()[row.first.trim()];
        final name = row.length > 1 ? row[1].trim() : '';
        if (type == null || type == TransactionType.fieldUpdate || name.isEmpty) {
          throw FormatException('Invalid Category "${row.join(',')}"');
        }
        categories.add(Category(id: newId(), name: name, type: type, createdAt: now));
      }
    }
    String? categoryIdFor(TransactionType type, String name) {
      if (name.isEmpty) return null;
      for (final c in categories) {
        if (c.type == type && c.name == name) return c.id;
      }
      return null;
    }

    final amounts = <String, double>{};
    final funds = <Fund>[];
    // Skip the marker and the header row.
    for (final row in rows.sublist(summaryStart + 2, summaryEnd)) {
      final label = row.first.trim();
      final amount = double.tryParse(row.length > 1 ? row[1].trim() : '');
      if (amount == null) throw FormatException('Invalid amount for "$label"');
      if (label.startsWith(_fundPrefix)) {
        funds.add(Fund(id: newId(), name: label.substring(_fundPrefix.length), amount: amount, createdAt: now));
      } else {
        amounts[label] = amount;
      }
    }
    for (final account in AccountBalances.accounts) {
      if (!amounts.containsKey(account)) throw FormatException('Missing balance for $account');
    }

    final transactionRows = rows.sublist(transactionsStart + 1);
    if (transactionRows.isEmpty) throw const FormatException('Missing transactions header');
    final header = transactionRows.first.map((h) => h.trim()).toList();
    final columnIndex = {for (final c in _Column.values) c: header.indexOf(c.header)};
    if (_Column.required.any((c) => columnIndex[c] == -1)) {
      throw const FormatException('Missing transaction columns');
    }

    final transactions = <FinanceTransaction>[];
    for (final (i, row) in transactionRows.skip(1).indexed) {
      String field(_Column c) {
        final col = columnIndex[c]!;
        return col >= 0 && col < row.length ? row[col] : '';
      }
      final rowLabel = 'transaction ${i + 1}';

      final date = DateTime.tryParse(field(_Column.dateTime).trim()) ?? DateTime.tryParse(field(_Column.date).trim());
      if (date == null) throw FormatException('Invalid date in $rowLabel');
      final type = TransactionType.values.asNameMap()[field(_Column.type).trim()];
      if (type == null) throw FormatException('Invalid type in $rowLabel');
      final amount = double.tryParse(field(_Column.amountK).trim());
      if (amount == null) throw FormatException('Invalid amount in $rowLabel');

      transactions.add(FinanceTransaction(
        id: newId(),
        type: type,
        account: field(_Column.account).trim(),
        amount: amount,
        date: date,
        note: field(_Column.note),
        previousValue: double.tryParse(field(_Column.previousValue).trim()),
        newValue: double.tryParse(field(_Column.newValue).trim()),
        categoryId: categoryIdFor(type, field(_Column.category).trim()),
      ));
    }

    return FinanceImport(
      balances: AccountBalances.fromAccounts(amounts),
      transactions: transactions,
      funds: funds,
      categories: categories,
    );
  }

  /// Splits CSV text into rows of fields, handling quoted fields that hold
  /// commas, doubled quotes or line breaks.
  static List<List<String>> _parseCsvRows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

String _escapeCsvField(String text) {
  if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
    final escaped = text.replaceAll('"', '""');
    return '"$escaped"';
  }
  return text;
}

/// The transactions log's columns, in the order the export writes them.
/// Import finds each one by [header], so older files may lack some.
enum _Column {
  date('date'),
  type('type'),
  account('account'),
  amountK('amount_k_vnd'),
  amountVnd('amount_vnd'),
  note('note'),
  previousValue('previous_value_k_vnd'),
  newValue('new_value_k_vnd'),
  dateTime('datetime'),
  category('category');

  final String header;
  const _Column(this.header);

  /// Present in every export, including those made before `datetime`.
  static const List<_Column> required = [date, type, account, amountK, note];

  /// [t]'s value in this column; [categoryNames] maps Category ids to names.
  String write(FinanceTransaction t, Map<String, String> categoryNames) {
    return switch (this) {
      date => t.formattedDate,
      type => t.type.name,
      account => _escapeCsvField(t.account),
      amountK => '${t.amount}',
      amountVnd => '${(t.amount * 1000).round()}',
      note => _escapeCsvField(t.note),
      previousValue => t.previousValue?.toString() ?? '',
      newValue => t.newValue?.toString() ?? '',
      dateTime => t.date.toIso8601String(),
      category => _escapeCsvField(categoryNames[t.categoryId] ?? ''),
    };
  }
}
