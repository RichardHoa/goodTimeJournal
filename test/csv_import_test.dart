import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/services/finance_csv.dart';
import 'package:mix_app/services/finance_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 10, 3, 9, 0);

  Future<FinanceProvider> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final provider = FinanceProvider(now: () => now);
    await provider.ready;
    return provider;
  }

  /// A transaction's stored form without its id, which import replaces.
  Map<String, dynamic> withoutId(FinanceTransaction t) => t.toJson()..remove('id');

  FinanceImport decode(String csv) {
    var next = 0;
    return FinanceCsv.decode(csv, newId: () => 'new${next++}', now: now);
  }

  setUp(() => now = DateTime(2026, 10, 3, 9, 0));

  group('FinanceCsv.decode', () {
    test('reads back what the export wrote, with new ids', () {
      final balances = AccountBalances(cash: 100.5, vcb: 200, mb: 3, techcombank: 4, mbInvestment: 300);
      final funds = [
        Fund(id: 'f1', name: 'Backup', amount: 50, createdAt: DateTime(2026, 8, 1)),
        Fund(id: 'f2', name: 'Trip, "Japan"', amount: 25.5, createdAt: DateTime(2026, 8, 2)),
      ];
      final transactions = [
        FinanceTransaction(
          id: 'a',
          type: TransactionType.moneyOut,
          account: 'VCB',
          amount: 12.5,
          date: DateTime(2026, 10, 2, 18, 45, 10),
          note: 'Dinner, "nice"\nwith friends',
          previousValue: 212.5,
          newValue: 200,
        ),
        FinanceTransaction(
          id: 'b',
          type: TransactionType.fieldUpdate,
          account: 'MB investment',
          amount: 50,
          date: DateTime(2026, 10, 1, 8, 0),
          note: 'Directly updated balance',
          previousValue: 250,
          newValue: 300,
        ),
        FinanceTransaction(
          id: 'c',
          type: TransactionType.moneyIn,
          account: 'Cash',
          amount: 100.5,
          date: DateTime(2026, 9, 30),
          note: '',
        ),
      ];

      final result = decode(FinanceCsv.encode(balances, transactions, funds));

      expect(result.balances.toJson(), balances.toJson());
      expect(result.funds.map((f) => (f.name, f.amount, f.createdAt)), [
        ('Backup', 50.0, now),
        ('Trip, "Japan"', 25.5, now),
      ]);
      expect(result.transactions.map(withoutId), transactions.map(withoutId));
      final ids = [...result.funds.map((f) => f.id), ...result.transactions.map((t) => t.id)];
      expect(ids.toSet(), hasLength(5));
      expect(ids.any(['f1', 'f2', 'a', 'b', 'c'].contains), false);
    });

    test('reads exports made before the datetime column, with CRLF and a BOM', () {
      const csv = '﻿--- ACCOUNT BALANCES SUMMARY ---\r\n'
          'Account,Amount (k VND),Amount (VND)\r\n'
          'Cash,10.0,10000\r\n'
          'VCB,0.0,0\r\n'
          'MB,0.0,0\r\n'
          'Techcombank,0.0,0\r\n'
          'MB investment,0.0,0\r\n'
          'Total Money,10.0,10000\r\n'
          'Funds total,0.0,0\r\n'
          'Money Left,10.0,10000\r\n'
          '\r\n'
          '--- TRANSACTIONS LOG ---\r\n'
          'date,type,account,amount_k_vnd,amount_vnd,note,previous_value_k_vnd,new_value_k_vnd\r\n'
          '2026-10-01,moneyIn,Cash,10.0,10000,Salary,0.0,10.0\r\n';

      final result = decode(csv);

      expect(result.balances.cash, 10.0);
      expect(result.funds, isEmpty);
      final tx = result.transactions.single;
      expect(tx.id, isNotEmpty);
      expect(tx.date, DateTime(2026, 10, 1));
      expect(tx.type, TransactionType.moneyIn);
      expect(tx.note, 'Salary');
      expect(tx.newValue, 10.0);
    });

    test('rejects files that are not a finance export', () {
      expect(() => decode('name,age\nBob,3\n'), throwsFormatException);
      expect(() => decode(''), throwsFormatException);

      final valid = FinanceCsv.encode(AccountBalances(), [
        FinanceTransaction(id: 'a', type: TransactionType.moneyIn, account: 'Cash', amount: 1, date: DateTime(2026), note: ''),
      ], []);
      expect(() => decode(valid.replaceFirst('VCB,0.0,0\n', '')), throwsFormatException);
      expect(() => decode(valid.replaceFirst('moneyIn', 'gift')), throwsFormatException);
    });
  });

  group('FinanceProvider.importData', () {
    test('replaces balances, transactions and Funds, keeps Trash, and sets the old data aside', () async {
      final source = await fresh();
      await source.recordMoneyIn(account: 'VCB', amount: 500, date: DateTime(2026, 10, 1), note: 'Salary');
      await source.recordMoneyOut(account: 'VCB', amount: 20, date: DateTime(2026, 10, 2), note: 'Lunch');
      await source.addFund(name: 'Rent', amount: 300);
      now = now.add(const Duration(minutes: 1));
      await source.addFund(name: 'Travel', amount: 100);
      final csv = FinanceCsv.encode(source.balances, source.transactions, source.funds);

      // A reinstalled app holding older data plus one trashed item.
      final target = await fresh();
      await target.recordMoneyIn(account: 'Cash', amount: 5, date: DateTime(2026, 9, 1), note: 'Old');
      await target.recordMoneyIn(account: 'Cash', amount: 7, date: DateTime(2026, 9, 2), note: 'Trashed');
      await target.deleteTransaction(target.transactions.first.id);
      await target.addFund(name: 'Old fund', amount: 1);

      await target.importData(target.readCsvExport(csv));

      expect(target.balances.toJson(), source.balances.toJson());
      expect(target.transactions.map(withoutId), source.transactions.map(withoutId));
      expect(target.funds.map((f) => f.name), ['Rent', 'Travel']);
      expect(target.moneyLeft, source.moneyLeft);
      expect(target.trash.single.transaction!.note, 'Trashed');

      final prefs = await SharedPreferences.getInstance();
      final oldTransactions = prefs.getString(FinanceMigration.asideKey(FinanceMigration.transactionsKey, 'before_import'));
      expect(oldTransactions, contains('"Old"'));

      // The imported data is what a later launch loads.
      final reloaded = FinanceProvider(now: () => now);
      await reloaded.ready;
      expect(reloaded.transactions.map((t) => t.note), ['Lunch', 'Salary']);
      expect(reloaded.funds.map((f) => f.name), ['Rent', 'Travel']);
    });

    test('a transaction restored from Trash never shares an id with an imported one', () async {
      final provider = await fresh();
      await provider.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime(2026, 10, 1), note: 'Lunch money');
      final csv = FinanceCsv.encode(provider.balances, provider.transactions, provider.funds);
      await provider.deleteTransaction(provider.transactions.single.id);

      await provider.importData(provider.readCsvExport(csv));
      await provider.restoreFromTrash(provider.trash.single.id);

      expect(provider.transactions.map((t) => t.note), ['Lunch money', 'Lunch money']);
      expect(provider.transactions.map((t) => t.id).toSet(), hasLength(2));

      // Each copy can be deleted on its own.
      await provider.deleteTransaction(provider.transactions.first.id);
      expect(provider.transactions, hasLength(1));
      expect(provider.balances.cash, 10);
    });

    test('a Fund restored from Trash goes back before Funds imported after it was made', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Old', amount: 1);
      await provider.deleteFund(provider.funds.single.id);
      now = now.add(const Duration(days: 1));
      final csv = FinanceCsv.encode(AccountBalances(), [], [
        Fund(id: 'x', name: 'First', amount: 2, createdAt: DateTime(2026)),
        Fund(id: 'y', name: 'Second', amount: 3, createdAt: DateTime(2026)),
      ]);

      await provider.importData(provider.readCsvExport(csv));
      await provider.restoreFromTrash(provider.trash.single.id);

      expect(provider.funds.map((f) => f.name), ['Old', 'First', 'Second']);
    });
  });
}
