import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _balancesKey = 'mixapp_finance_balances';
const _transactionsKey = 'mixapp_finance_transactions';
const _versionKey = 'mixapp_finance_data_version';
const _balancesBackupKey = 'mixapp_finance_balances_backup_v1';
const _transactionsBackupKey = 'mixapp_finance_transactions_backup_v1';
const _fundsKey = 'mixapp_finance_funds';

Map<String, dynamic> _record({
  required String id,
  required String type,
  required String account,
  required double amount,
  required String date,
  String note = '',
  double? previousValue,
  double? newValue,
}) {
  return {
    'id': id,
    'type': type,
    'account': account,
    'amount': amount,
    'date': date,
    'note': note,
    'previousValue': previousValue,
    'newValue': newValue,
  };
}

/// v1 data whose transactions replay exactly to its balances.
final _v1Balances = {
  'cash': 150.0,
  'vcb': 300.0,
  'mb': 50.0,
  'techcombank': 0.0,
  'mbFund': 1000.0,
  'backupFund': 200.0,
};

final _v1Transactions = [
  _record(id: 't7', type: 'fieldUpdate', account: 'Backup Fund', amount: 200, date: '2026-01-07T09:00:00.000', note: 'Reserve', previousValue: 0, newValue: 200),
  _record(id: 't6', type: 'moneyIn', account: 'MB', amount: 50, date: '2026-01-06T09:00:00.000', note: 'Gift', previousValue: 0, newValue: 50),
  _record(id: 't5', type: 'fieldUpdate', account: 'MB fund', amount: 1000, date: '2026-01-05T09:00:00.000', note: 'Invested', previousValue: 0, newValue: 1000),
  _record(id: 't4', type: 'fieldUpdate', account: 'VCB', amount: 300, date: '2026-01-04T09:00:00.000', note: 'Opening VCB', previousValue: 0, newValue: 300),
  _record(id: 't3', type: 'fieldUpdate', account: 'Cash', amount: 20, date: '2026-01-03T09:00:00.000', note: 'Lost some cash', previousValue: 170, newValue: 150),
  _record(id: 't2', type: 'moneyIn', account: 'Cash', amount: 70, date: '2026-01-02T09:00:00.000', note: 'Salary', previousValue: 100, newValue: 170),
  _record(id: 't1', type: 'fieldUpdate', account: 'Cash', amount: 100, date: '2026-01-01T09:00:00.000', note: 'Opening cash', previousValue: 0, newValue: 100),
];

Future<SharedPreferences> _seed({Object? balances, Object? transactions, int? version}) async {
  SharedPreferences.setMockInitialValues({
    if (balances != null) _balancesKey: balances is String ? balances : jsonEncode(balances),
    if (transactions != null) _transactionsKey: transactions is String ? transactions : jsonEncode(transactions),
    _versionKey: ?version,
  });
  return SharedPreferences.getInstance();
}

final _now = DateTime(2026, 9, 1, 10, 30);

Future<FinanceProvider> _load() async {
  final provider = FinanceProvider(now: () => _now);
  await provider.ready;
  return provider;
}

double _balanceOf(AccountBalances b, String account) {
  switch (account) {
    case 'Cash':
      return b.cash;
    case 'VCB':
      return b.vcb;
    case 'MB':
      return b.mb;
    case 'Techcombank':
      return b.techcombank;
    case 'MB investment':
      return b.mbInvestment;
  }
  throw ArgumentError(account);
}

/// Sums each record's signed effect on its account, starting from zero.
Map<String, double> _replay(List<FinanceTransaction> transactions) {
  final totals = <String, double>{};
  for (final t in transactions) {
    final double effect;
    switch (t.type) {
      case TransactionType.moneyIn:
        effect = t.amount;
      case TransactionType.moneyOut:
        effect = -t.amount;
      case TransactionType.fieldUpdate:
        effect = t.newValue! - t.previousValue!;
    }
    totals[t.account] = (totals[t.account] ?? 0) + effect;
  }
  return totals;
}

FinanceTransaction _byId(FinanceProvider p, String id) => p.transactions.firstWhere((t) => t.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1 → current conversion', () {
    test('Liquid account updates become Money In for increases and Money Out for decreases', () async {
      await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      final opening = _byId(provider, 't1');
      expect(opening.type, TransactionType.moneyIn);
      expect(opening.account, 'Cash');
      expect(opening.amount, 100.0);
      expect(opening.note, 'Opening cash');
      expect(opening.date, DateTime(2026, 1, 1, 9));
      expect(opening.previousValue, 0.0);
      expect(opening.newValue, 100.0);

      final lost = _byId(provider, 't3');
      expect(lost.type, TransactionType.moneyOut);
      expect(lost.amount, 20.0);
      expect(lost.note, 'Lost some cash');
      expect(lost.date, DateTime(2026, 1, 3, 9));
      expect(lost.previousValue, 170.0);
      expect(lost.newValue, 150.0);

      expect(_byId(provider, 't4').type, TransactionType.moneyIn);
      expect(_byId(provider, 't4').amount, 300.0);
    });

    test('the amount is the difference even when the stored amount disagrees', () async {
      await _seed(balances: {'cash': 40.0}, transactions: [
        _record(id: 'x', type: 'fieldUpdate', account: 'Cash', amount: 999, date: '2026-01-01T09:00:00.000', previousValue: 100, newValue: 40),
      ]);
      final provider = await _load();

      expect(_byId(provider, 'x').type, TransactionType.moneyOut);
      expect(_byId(provider, 'x').amount, 60.0);
    });

    test('every balance is identical before and after', () async {
      await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      final b = provider.balances;
      expect(b.cash, 150.0);
      expect(b.vcb, 300.0);
      expect(b.mb, 50.0);
      expect(b.techcombank, 0.0);
      expect(b.mbInvestment, 1000.0);
      expect(b.totalMoney, 1500.0);
    });

    test('replaying records from zero still gives each current balance', () async {
      await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      final replayed = _replay(provider.transactions);
      for (final account in ['Cash', 'VCB', 'MB', 'MB investment']) {
        expect(replayed[account], _balanceOf(provider.balances, account), reason: account);
      }
    });

    test('MB fund becomes MB investment in balances and records, and stays a Balance update', () async {
      final prefs = await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      final invested = _byId(provider, 't5');
      expect(invested.account, 'MB investment');
      expect(invested.type, TransactionType.fieldUpdate);
      expect(invested.isBalanceUpdate, true);
      expect(invested.previousValue, 0.0);
      expect(invested.newValue, 1000.0);
      expect(provider.transactions.any((t) => t.account == 'MB fund'), false);

      final storedBalances = jsonDecode(prefs.getString(_balancesKey)!) as Map<String, dynamic>;
      expect(storedBalances['mbInvestment'], 1000.0);
      expect(storedBalances.containsKey('mbFund'), false);
      expect(prefs.getString(_transactionsKey)!.contains('MB fund'), false);
    });

    test('the data version is set to 3', () async {
      final prefs = await _seed(balances: _v1Balances, transactions: _v1Transactions);
      await _load();

      expect(prefs.getInt(_versionKey), 3);
    });

    test('the Backup Fund amount becomes a "Backup" Fund and its records are removed', () async {
      final prefs = await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      final backup = provider.funds.single;
      expect(backup.name, 'Backup');
      expect(backup.amount, 200.0);
      expect(provider.fundsTotal, 200.0);
      expect(provider.moneyLeft, 1300.0);
      expect(provider.transactions.any((t) => t.account == 'Backup Fund'), false);
      expect(provider.transactions.length, _v1Transactions.length - 1);

      final storedBalances = jsonDecode(prefs.getString(_balancesKey)!) as Map<String, dynamic>;
      expect(storedBalances.containsKey('backupFund'), false);
      expect(prefs.getString(_transactionsKey)!.contains('Backup Fund'), false);
      expect((jsonDecode(prefs.getString(_fundsKey)!) as List).single['name'], 'Backup');
    });

    test('a zero Backup Fund creates no Fund', () async {
      await _seed(balances: {..._v1Balances, 'backupFund': 0.0}, transactions: [
        _record(id: 'b', type: 'fieldUpdate', account: 'Backup Fund', amount: 50, date: '2026-01-01T09:00:00.000', previousValue: 50, newValue: 0),
      ]);
      final provider = await _load();

      expect(provider.funds, isEmpty);
      expect(provider.transactions, isEmpty);
      expect(provider.balances.totalMoney, 1500.0);
    });

    test('data already converted to v2 still gets its Backup Fund turned into a Fund', () async {
      final prefs = await _seed(
        version: 2,
        balances: {'cash': 100.0, 'mbInvestment': 50.0, 'backupFund': 30.0},
        transactions: [
          _record(id: 'b', type: 'fieldUpdate', account: 'Backup Fund', amount: 30, date: '2026-01-01T09:00:00.000', previousValue: 0, newValue: 30),
          _record(id: 'c', type: 'moneyIn', account: 'Cash', amount: 100, date: '2026-01-02T09:00:00.000', previousValue: 0, newValue: 100),
        ],
      );
      final provider = await _load();

      expect(provider.funds.single.name, 'Backup');
      expect(provider.funds.single.amount, 30.0);
      expect(provider.transactions.map((t) => t.id), ['c']);
      expect(provider.balances.cash, 100.0);
      expect(provider.balances.mbInvestment, 50.0);
      expect(prefs.getInt(_versionKey), 3);
    });

    test('converting from v2 backs up the v2 strings under their own keys', () async {
      final rawBalances = jsonEncode({'cash': 100.0, 'backupFund': 30.0});
      final rawTransactions = jsonEncode([
        _record(id: 'b', type: 'fieldUpdate', account: 'Backup Fund', amount: 30, date: '2026-01-01T09:00:00.000', previousValue: 0, newValue: 30),
      ]);
      final prefs = await _seed(version: 2, balances: rawBalances, transactions: rawTransactions);
      await _load();

      expect(prefs.getString('mixapp_finance_balances_backup_v2'), rawBalances);
      expect(prefs.getString('mixapp_finance_transactions_backup_v2'), rawTransactions);
      expect(prefs.getString(_balancesBackupKey), isNull);
    });

    test('backup keys hold the original raw strings', () async {
      final rawBalances = jsonEncode(_v1Balances);
      final rawTransactions = jsonEncode(_v1Transactions);
      final prefs = await _seed(balances: rawBalances, transactions: rawTransactions);
      await _load();

      expect(prefs.getString(_balancesBackupKey), rawBalances);
      expect(prefs.getString(_transactionsBackupKey), rawTransactions);
    });

    test('a converted record can be edited and deleted like a native one', () async {
      await _seed(balances: _v1Balances, transactions: _v1Transactions);
      final provider = await _load();

      await provider.updateTransaction(
        id: 't3',
        newAccount: 'Cash',
        newAmount: 30.0,
        newDate: DateTime(2026, 1, 3, 9),
        newNote: 'Lost more cash',
      );
      expect(provider.balances.cash, 140.0);
      expect(_byId(provider, 't3').type, TransactionType.moneyOut);

      await provider.deleteTransaction('t1');
      expect(provider.balances.cash, 40.0);
      expect(provider.transactions.any((t) => t.id == 't1'), false);

      await provider.restoreFromTrash(provider.trash.single.id);
      expect(provider.balances.cash, 140.0);
      final restored = _byId(provider, 't1');
      expect(restored.type, TransactionType.moneyIn);
      expect(restored.note, 'Opening cash');
      expect(restored.date, DateTime(2026, 1, 1, 9));
    });

    test('loading again, or loading a fresh provider on converted data, changes nothing', () async {
      final prefs = await _seed(balances: _v1Balances, transactions: _v1Transactions);
      await _load();
      final balancesAfterFirst = prefs.getString(_balancesKey);
      final transactionsAfterFirst = prefs.getString(_transactionsKey);
      final fundsAfterFirst = prefs.getString(_fundsKey);

      final second = await _load();
      final third = await _load();

      expect(prefs.getString(_balancesKey), balancesAfterFirst);
      expect(prefs.getString(_transactionsKey), transactionsAfterFirst);
      expect(prefs.getString(_fundsKey), fundsAfterFirst);
      expect(second.funds.length, 1);
      expect(prefs.getInt(_versionKey), 3);
      expect(prefs.getString(_balancesBackupKey), jsonEncode(_v1Balances));
      expect(second.balances.cash, 150.0);
      expect(third.transactions.length, _v1Transactions.length - 1);
    });

    test('fresh install with no data loads empty and is stamped as v3', () async {
      final prefs = await _seed();
      final provider = await _load();

      expect(provider.transactions, isEmpty);
      expect(provider.balances.totalMoney, 0.0);
      expect(provider.funds, isEmpty);
      expect(prefs.getInt(_versionKey), 3);
      expect(prefs.getString(_balancesBackupKey), isNull);
      expect(prefs.getString(_transactionsBackupKey), isNull);
    });
  });

  group('v1 → current conversion with partial or malformed data', () {
    test('records missing previous or new values keep their amount and stay Balance updates', () async {
      await _seed(balances: {'cash': 25.0}, transactions: [
        _record(id: 'p', type: 'fieldUpdate', account: 'Cash', amount: 25, date: '2026-01-01T09:00:00.000', previousValue: 0),
      ]);
      final provider = await _load();

      final tx = _byId(provider, 'p');
      expect(tx.type, TransactionType.fieldUpdate);
      expect(tx.amount, 25.0);
      expect(provider.balances.cash, 25.0);
    });

    test('records on an unknown account are left as they are', () async {
      await _seed(balances: {'cash': 0.0}, transactions: [
        _record(id: 'u', type: 'fieldUpdate', account: 'Crypto', amount: 5, date: '2026-01-01T09:00:00.000', previousValue: 0, newValue: 5),
      ]);
      final provider = await _load();

      final tx = _byId(provider, 'u');
      expect(tx.type, TransactionType.fieldUpdate);
      expect(tx.account, 'Crypto');
      expect(tx.amount, 5.0);
    });

    test('bad transactions JSON does not crash, writes nothing and does not bump the version', () async {
      final rawBalances = jsonEncode(_v1Balances);
      final prefs = await _seed(balances: rawBalances, transactions: '[{not json');
      final provider = await _load();

      expect(prefs.getInt(_versionKey), isNull);
      expect(prefs.getString(_balancesKey), rawBalances);
      expect(prefs.getString(_transactionsKey), '[{not json');
      expect(prefs.getString(_balancesBackupKey), isNull);
      expect(prefs.getString(_fundsKey), isNull);
      expect(provider.balances.mbInvestment, 1000.0);
      expect(provider.balances.cash, 150.0);
    });

    test('unreadable stored data is kept aside before the next save overwrites it', () async {
      final prefs = await _seed(balances: 'nope', transactions: '[{not json');
      final provider = await _load();

      await provider.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime(2026, 2, 1), note: 'After');

      expect(prefs.getString('${_balancesKey}_unreadable'), 'nope');
      expect(prefs.getString('${_transactionsKey}_unreadable'), '[{not json');
      expect(provider.transactions.single.note, 'After');
    });

    test('bad balances JSON does not crash and does not bump the version', () async {
      final rawTransactions = jsonEncode(_v1Transactions);
      final prefs = await _seed(balances: 'nope', transactions: rawTransactions);
      final provider = await _load();

      expect(prefs.getInt(_versionKey), isNull);
      expect(prefs.getString(_transactionsKey), rawTransactions);
      expect(provider.transactions.length, _v1Transactions.length);
    });

    test('a transactions list with non-record entries does not bump the version', () async {
      final prefs = await _seed(balances: _v1Balances, transactions: [1, 'two']);
      await _load();

      expect(prefs.getInt(_versionKey), isNull);
      expect(prefs.getString(_transactionsKey), jsonEncode([1, 'two']));
    });
  });
}
