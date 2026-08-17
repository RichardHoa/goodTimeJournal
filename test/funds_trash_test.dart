import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _trashKey = 'mixapp_finance_trash';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 9, 1, 10, 30);

  Future<FinanceProvider> load() async {
    final provider = FinanceProvider(now: () => now);
    await provider.ready;
    return provider;
  }

  Future<FinanceProvider> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return load();
  }

  setUp(() => now = DateTime(2026, 9, 1, 10, 30));

  group('Funds', () {
    test('Funds can be added and edited, and are listed in creation order', () async {
      final provider = await fresh();

      expect(await provider.addFund(name: 'Backup', amount: 200), isNull);
      now = now.add(const Duration(minutes: 1));
      expect(await provider.addFund(name: 'Travel', amount: 50), isNull);
      now = now.add(const Duration(minutes: 1));
      expect(await provider.addFund(name: 'Gifts', amount: 10), isNull);

      expect(provider.funds.map((f) => f.name), ['Backup', 'Travel', 'Gifts']);

      final travel = provider.funds[1];
      expect(await provider.updateFund(travel.id, name: 'Japan trip', amount: 80), isNull);

      expect(provider.funds.map((f) => f.name), ['Backup', 'Japan trip', 'Gifts']);
      expect(provider.funds[1].amount, 80.0);
      expect(provider.fundsTotal, 290.0);
    });

    test('empty or duplicate names are rejected, trimmed and case-insensitive', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Backup', amount: 200);
      await provider.addFund(name: 'Travel', amount: 50);

      expect(await provider.addFund(name: '   ', amount: 10), isNotNull);
      expect(await provider.addFund(name: '  backup ', amount: 10), isNotNull);
      expect(await provider.updateFund(provider.funds[1].id, name: 'BACKUP', amount: 50), isNotNull);
      expect(provider.funds.map((f) => f.name), ['Backup', 'Travel']);

      // Keeping its own name (in another case) is fine.
      expect(await provider.updateFund(provider.funds[1].id, name: ' travel ', amount: 60), isNull);
      expect(provider.funds[1].name, 'travel');
    });

    test('Money Left is Total Money minus all Funds, and can go negative', () async {
      final provider = await fresh();
      await provider.updateAccountField('Cash', 300);
      await provider.updateAccountField('MB investment', 200);
      await provider.addFund(name: 'Backup', amount: 100);
      await provider.addFund(name: 'Travel', amount: 50);

      expect(provider.moneyLeft, 350.0);

      await provider.addFund(name: 'House', amount: 1000);
      expect(provider.moneyLeft, -650.0);
    });

    test('Fund changes stay out of Transaction History', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Backup', amount: 100);
      await provider.updateFund(provider.funds.single.id, name: 'Backup', amount: 150);
      await provider.deleteFund(provider.funds.single.id);

      expect(provider.transactions, isEmpty);
    });
  });

  group('Trash', () {
    test('deleting a transaction reverses its balance effect and puts it in Trash', () async {
      final provider = await fresh();
      await provider.recordMoneyIn(account: 'Cash', amount: 100, date: DateTime(2026, 8, 1), note: 'Salary');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 8, 2), note: 'Lunch');
      final lunch = provider.transactions.first;

      await provider.deleteTransaction(lunch.id);

      expect(provider.balances.cash, 100.0);
      expect(provider.transactions.map((t) => t.note), ['Salary']);
      final item = provider.trash.single;
      expect(item.kind, TrashKind.transaction);
      expect(item.transaction!.id, lunch.id);
      expect(item.deletedAt, now);
    });

    test('restoring a transaction re-applies its amount to the current balance and keeps id, date and note', () async {
      final provider = await fresh();
      await provider.updateAccountField('Cash', 500);
      await provider.recordMoneyOut(account: 'Cash', amount: 80, date: DateTime(2026, 8, 2), note: 'Dinner');
      final dinner = provider.transactions.first;
      await provider.deleteTransaction(dinner.id);
      await provider.updateAccountField('Cash', 1000);

      final error = await provider.restoreFromTrash(provider.trash.single.id);

      expect(error, isNull);
      expect(provider.balances.cash, 920.0);
      expect(provider.trash, isEmpty);
      final restored = provider.transactions.firstWhere((t) => t.id == dinner.id);
      expect(restored.date, dinner.date);
      expect(restored.note, 'Dinner');
      expect(restored.type, TransactionType.moneyOut);
      expect(restored.amount, 80.0);
    });

    test('a Balance update can be deleted and restored', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB investment', 100);
      await provider.updateAccountField('MB investment', 300);

      await provider.deleteTransaction(provider.transactions.first.id);
      expect(provider.balances.mbInvestment, 100.0);

      await provider.restoreFromTrash(provider.trash.single.id);
      expect(provider.balances.mbInvestment, 300.0);
    });

    test('a Fund deleted goes to Trash and can be restored', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Travel', amount: 50);
      final travel = provider.funds.single;

      await provider.deleteFund(travel.id);
      expect(provider.funds, isEmpty);
      expect(provider.trash.single.kind, TrashKind.fund);
      expect(provider.trash.single.fund!.name, 'Travel');

      expect(await provider.restoreFromTrash(provider.trash.single.id), isNull);
      expect(provider.funds.single.name, 'Travel');
      expect(provider.funds.single.amount, 50.0);
      expect(provider.funds.single.id, travel.id);
      expect(provider.trash, isEmpty);
    });

    test('a restored Fund goes back to its creation-order place', () async {
      final provider = await fresh();
      await provider.addFund(name: 'A', amount: 1);
      now = now.add(const Duration(minutes: 1));
      await provider.addFund(name: 'B', amount: 1);
      now = now.add(const Duration(minutes: 1));
      await provider.addFund(name: 'C', amount: 1);

      await provider.deleteFund(provider.funds.first.id);
      await provider.restoreFromTrash(provider.trash.single.id);

      expect(provider.funds.map((f) => f.name), ['A', 'B', 'C']);
    });

    test('restoring a Fund whose name is now taken fails with a clear message', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Travel', amount: 50);
      await provider.deleteFund(provider.funds.single.id);
      await provider.addFund(name: 'travel', amount: 70);

      final error = await provider.restoreFromTrash(provider.trash.single.id);

      expect(error, contains('Travel'));
      expect(provider.funds.single.amount, 70.0);
      expect(provider.trash.length, 1);
    });

    test('delete forever removes one item and empty trash removes everything', () async {
      final provider = await fresh();
      await provider.recordMoneyIn(account: 'VCB', amount: 10, date: DateTime(2026, 8, 1), note: 'a');
      await provider.recordMoneyIn(account: 'VCB', amount: 20, date: DateTime(2026, 8, 2), note: 'b');
      await provider.addFund(name: 'Travel', amount: 50);
      for (final t in provider.transactions.toList()) {
        await provider.deleteTransaction(t.id);
      }
      await provider.deleteFund(provider.funds.single.id);
      expect(provider.trash.length, 3);

      await provider.deleteForever(provider.trash.first.id);
      expect(provider.trash.length, 2);
      expect(provider.balances.vcb, 0.0);

      await provider.emptyTrash();
      expect(provider.trash, isEmpty);
      expect((await load()).trash, isEmpty);
    });

    test('items more than 30 days old are purged on load, exactly 30 days are kept', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Old', amount: 1);
      await provider.deleteFund(provider.funds.single.id);
      now = now.add(const Duration(seconds: 1));
      await provider.addFund(name: 'Newer', amount: 1);
      await provider.deleteFund(provider.funds.single.id);
      final deletedAt = now.subtract(const Duration(seconds: 1));

      now = deletedAt.add(const Duration(days: 30));
      expect((await load()).trash.length, 2);

      now = deletedAt.add(const Duration(days: 30, milliseconds: 1));
      final reloaded = await load();
      expect(reloaded.trash.map((i) => i.fund!.name), ['Newer']);

      final stored = jsonDecode((await SharedPreferences.getInstance()).getString(_trashKey)!) as List;
      expect(stored.length, 1);
    });

    test('days left counts down from 30', () async {
      final provider = await fresh();
      await provider.addFund(name: 'Travel', amount: 50);
      await provider.deleteFund(provider.funds.single.id);

      expect(provider.daysLeftInTrash(provider.trash.single), 30);
      now = now.add(const Duration(days: 7, hours: 1));
      expect(provider.daysLeftInTrash(provider.trash.single), 23);
    });

    test('Trash is listed with the most recently deleted first', () async {
      final provider = await fresh();
      await provider.addFund(name: 'A', amount: 1);
      await provider.addFund(name: 'B', amount: 1);
      await provider.deleteFund(provider.funds.first.id);
      now = now.add(const Duration(minutes: 1));
      await provider.deleteFund(provider.funds.first.id);

      expect(provider.trash.map((i) => i.fund!.name), ['B', 'A']);
    });
  });

  test('Funds, Trash and balances all survive a reload', () async {
    final provider = await fresh();
    await provider.updateAccountField('Techcombank', 400);
    await provider.recordMoneyOut(account: 'Techcombank', amount: 40, date: DateTime(2026, 8, 3), note: 'Taxi');
    await provider.addFund(name: 'Backup', amount: 100);
    await provider.addFund(name: 'Travel', amount: 25);
    await provider.deleteFund(provider.funds.last.id);
    await provider.deleteTransaction(provider.transactions.first.id);

    final reloaded = await load();

    expect(reloaded.balances.techcombank, 400.0);
    expect(reloaded.funds.map((f) => f.name), ['Backup']);
    expect(reloaded.moneyLeft, 300.0);
    expect(reloaded.trash.length, 2);
    expect(reloaded.trash.map((i) => i.kind), [TrashKind.transaction, TrashKind.fund]);
    expect(reloaded.trash.first.transaction!.note, 'Taxi');

    await reloaded.restoreFromTrash(reloaded.trash.first.id);
    expect(reloaded.balances.techcombank, 360.0);
  });
}
