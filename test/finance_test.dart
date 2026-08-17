import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/services/finance_csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: AccountBalances & FinanceTransaction Model Unit Tests', () {
    test('AccountBalances totalMoney and totalLiquid calculations', () {
      final balances = AccountBalances(
        cash: 100.0,
        vcb: 200.0,
        mb: 300.0,
        techcombank: 400.0,
        mbInvestment: 500.0,
      );

      expect(balances.totalLiquid, 1000.0);
      expect(balances.totalMoney, 1500.0);
    });

    test('AccountBalances copyWith updates specified fields only', () {
      final initial = AccountBalances(cash: 50.0, vcb: 100.0);
      final updated = initial.copyWith(cash: 75.0, mbInvestment: 20.0);

      expect(updated.cash, 75.0);
      expect(updated.vcb, 100.0);
      expect(updated.mbInvestment, 20.0);
    });

    test('AccountBalances toJson and fromJson fidelity (handles ints & double values)', () {
      final json = {
        'cash': 100, // integer input
        'vcb': 200.55,
        'mb': 300,
        'techcombank': 400.0,
        'mbInvestment': 500.25,
      };

      final balances = AccountBalances.fromJson(json);
      expect(balances.cash, 100.0);
      expect(balances.vcb, 200.55);
      expect(balances.mbInvestment, 500.25);

      final exportedJson = balances.toJson();
      expect(exportedJson['cash'], 100.0);
      expect(exportedJson['mbInvestment'], 500.25);
      expect(exportedJson.containsKey('backupFund'), false);
    });

    test('FinanceTransaction.fromJson fallback handling for missing/invalid data', () {
      final invalidJson = <String, dynamic>{
        'type': 'unknownType',
        'date': 'invalid-date-format',
      };

      final tx = FinanceTransaction.fromJson(invalidJson);
      expect(tx.type, TransactionType.moneyIn); // fallback to moneyIn
      expect(tx.account, '');
      expect(tx.amount, 0.0);
      expect(tx.id.isNotEmpty, true);
    });
  });

  group('Group 2: Normal Balance Updates & Cashflow Operations', () {
    test('recordMoneyIn updates liquid accounts correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      for (final account in FinanceProvider.liquidAccounts) {
        await provider.recordMoneyIn(
          account: account,
          amount: 100.0,
          date: DateTime(2026, 8, 17),
          note: 'Salary to $account',
        );
      }

      expect(provider.balances.cash, 100.0);
      expect(provider.balances.vcb, 100.0);
      expect(provider.balances.mb, 100.0);
      expect(provider.balances.techcombank, 100.0);
      expect(provider.balances.totalLiquid, 400.0);
      expect(provider.transactions.length, 4);
    });

    test('recordMoneyOut reduces liquid accounts correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'VCB',
        amount: 500.0,
        date: DateTime(2026, 8, 17),
        note: 'Initial deposit',
      );

      await provider.recordMoneyOut(
        account: 'VCB',
        amount: 150.0,
        date: DateTime(2026, 8, 17),
        note: 'Bill payment',
      );

      expect(provider.balances.vcb, 350.0);
      expect(provider.transactions.first.type, TransactionType.moneyOut);
      expect(provider.transactions.first.previousValue, 500.0);
      expect(provider.transactions.first.newValue, 350.0);
    });

    test('updateAccountField updates liquid accounts and MB investment, and ignores Backup Fund', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.updateAccountField('Cash', 250.0);
      await provider.updateAccountField('MB investment', 1000.0);
      await provider.updateAccountField('Backup Fund', 300.0);

      expect(provider.balances.cash, 250.0);
      expect(provider.balances.mbInvestment, 1000.0);
      expect(provider.balances.totalMoney, 1250.0);
      expect(provider.moneyLeft, 1250.0);
      expect(provider.transactions.length, 2);
    });
  });

  group('Balance adjustments & Balance updates', () {
    final fixedNow = DateTime(2026, 9, 1, 10, 30);

    Future<FinanceProvider> freshProvider() async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider(now: () => fixedNow);
      await provider.ready;
      return provider;
    }

    test('raising a Liquid account records a Money In for the difference', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('Cash', 250.0);

      final tx = provider.transactions.single;
      expect(tx.type, TransactionType.moneyIn);
      expect(tx.account, 'Cash');
      expect(tx.amount, 250.0);
      expect(tx.note, 'Balance adjustment');
      expect(tx.previousValue, 0.0);
      expect(tx.newValue, 250.0);
      expect(tx.date, fixedNow);
      expect(provider.balances.cash, 250.0);
    });

    test('lowering a Liquid account records a Money Out for the difference', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('VCB', 400.0);
      await provider.updateAccountField('VCB', 150.0);

      final tx = provider.transactions.first;
      expect(tx.type, TransactionType.moneyOut);
      expect(tx.account, 'VCB');
      expect(tx.amount, 250.0);
      expect(tx.note, 'Balance adjustment');
      expect(tx.previousValue, 400.0);
      expect(tx.newValue, 150.0);
      expect(provider.balances.vcb, 150.0);
    });

    test('a custom note replaces the default Balance adjustment note', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('MB', 80.0, customNote: 'Found in drawer');

      expect(provider.transactions.single.note, 'Found in drawer');
    });

    test('an edit that leaves the balance unchanged records nothing', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('Techcombank', 100.0);
      await provider.updateAccountField('Techcombank', 100.0);
      await provider.updateAccountField('MB investment', 0.0);

      expect(provider.transactions.length, 1);
      expect(provider.balances.techcombank, 100.0);
    });

    test('editing MB investment records a Balance update with previous and new values', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('MB investment', 1000.0);
      await provider.updateAccountField('MB investment', 900.0);

      final tx = provider.transactions.first;
      expect(tx.type, TransactionType.fieldUpdate);
      expect(tx.account, 'MB investment');
      expect(tx.previousValue, 1000.0);
      expect(tx.newValue, 900.0);
      expect(tx.isBalanceUpdate, true);
      expect(provider.balances.mbInvestment, 900.0);
      expect(provider.balances.totalMoney, 900.0);
    });

    test('a Balance adjustment can be edited and deleted like any Money In/Out', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('Cash', 100.0);
      final id = provider.transactions.single.id;

      await provider.updateTransaction(
        id: id,
        newAccount: 'Cash',
        newAmount: 60.0,
        newDate: fixedNow,
        newNote: 'Balance adjustment',
      );
      expect(provider.balances.cash, 60.0);
      expect(provider.transactions.single.type, TransactionType.moneyIn);

      await provider.deleteTransaction(id);
      expect(provider.balances.cash, 0.0);
      expect(provider.transactions, isEmpty);
    });

    test('only MB investment Balance updates count as Updates', () async {
      final provider = await freshProvider();

      await provider.updateAccountField('Cash', 100.0);
      await provider.updateAccountField('MB investment', 500.0);
      await provider.updateAccountField('Backup Fund', 50.0);

      final updates = provider.transactions.where((t) => t.isBalanceUpdate).toList();
      expect(updates.map((t) => t.account), ['MB investment']);
    });
  });

  group('Group 3: Transaction Deletion & Reversion Tests', () {
    test('deleteTransaction reverts moneyIn correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'MB',
        amount: 200.0,
        date: DateTime(2026, 8, 17),
        note: 'Deposit',
      );
      expect(provider.balances.mb, 200.0);

      final txId = provider.transactions.first.id;
      await provider.deleteTransaction(txId);

      expect(provider.balances.mb, 0.0);
      expect(provider.transactions.isEmpty, true);
    });

    test('deleteTransaction restores moneyOut correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.updateAccountField('Techcombank', 500.0);
      await provider.recordMoneyOut(
        account: 'Techcombank',
        amount: 120.0,
        date: DateTime(2026, 8, 17),
        note: 'Shopping',
      );
      expect(provider.balances.techcombank, 380.0);

      final outTxId = provider.transactions.first.id;
      await provider.deleteTransaction(outTxId);

      expect(provider.balances.techcombank, 500.0);
    });

    test('deleteTransaction reverts a Balance update correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.updateAccountField('MB investment', 100.0);
      await provider.updateAccountField('MB investment', 300.0);
      expect(provider.balances.mbInvestment, 300.0);

      final secondFieldTxId = provider.transactions.first.id;
      await provider.deleteTransaction(secondFieldTxId);

      expect(provider.balances.mbInvestment, 100.0);
    });

    test('deleteTransaction on non-existent ID does not mutate state', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 50.0,
        date: DateTime(2026, 8, 17),
        note: 'Test',
      );

      await provider.deleteTransaction('non_existent_id');

      expect(provider.balances.cash, 50.0);
      expect(provider.transactions.length, 1);
    });
  });

  group('Group 4: Transaction Editing & Modification Tests', () {
    test('updateTransaction modifies moneyIn amount and switches target account', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 100.0,
        date: DateTime(2026, 8, 17),
        note: 'Bonus',
      );

      final txId = provider.transactions.first.id;
      await provider.updateTransaction(
        id: txId,
        newAccount: 'VCB',
        newAmount: 250.0,
        newDate: DateTime(2026, 8, 17),
        newNote: 'Bonus transferred to VCB',
      );

      final updatedTx = provider.transactions.firstWhere((t) => t.id == txId);
      expect(provider.balances.cash, 0.0); // Reverted Cash
      expect(provider.balances.vcb, 250.0); // Applied to VCB
      expect(updatedTx.account, 'VCB');
      expect(updatedTx.amount, 250.0);
    });

    test('updateTransaction modifies moneyOut amount', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.updateAccountField('MB', 500.0);
      await provider.recordMoneyOut(
        account: 'MB',
        amount: 100.0,
        date: DateTime(2026, 8, 17),
        note: 'Lunch',
      );
      expect(provider.balances.mb, 400.0);

      final outTxId = provider.transactions.first.id;
      await provider.updateTransaction(
        id: outTxId,
        newAccount: 'MB',
        newAmount: 150.0,
        newDate: DateTime(2026, 8, 17),
        newNote: 'Expensive Lunch',
      );

      final updatedTx = provider.transactions.firstWhere((t) => t.id == outTxId);
      expect(provider.balances.mb, 350.0);
      expect(updatedTx.amount, 150.0);
    });

    test('updateTransaction rejects non-positive amount edit (amount <= 0)', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 100.0,
        date: DateTime(2026, 8, 17),
        note: 'Valid',
      );

      final txId = provider.transactions.first.id;
      await provider.updateTransaction(
        id: txId,
        newAccount: 'Cash',
        newAmount: 0.0,
        newDate: DateTime(2026, 8, 17),
        newNote: 'Zero amount attempt',
      );

      // Verify transaction was NOT modified
      expect(provider.balances.cash, 100.0);
      expect(provider.transactions.first.amount, 100.0);
    });
  });

  group('Group 5: Defensive Edge-Case Handling Tests', () {
    test('recordMoneyIn and recordMoneyOut ignore MB investment and Backup Fund', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'MB investment',
        amount: 500.0,
        date: DateTime(2026, 8, 17),
        note: 'Invalid cashflow target',
      );

      await provider.recordMoneyOut(
        account: 'Backup Fund',
        amount: 100.0,
        date: DateTime(2026, 8, 17),
        note: 'Invalid cashflow target',
      );

      expect(provider.balances.mbInvestment, 0.0);
      expect(provider.balances.totalMoney, 0.0);
      expect(provider.transactions.isEmpty, true);
    });

    test('recordMoneyIn and recordMoneyOut ignore non-positive amounts (amount <= 0)', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 0.0,
        date: DateTime(2026, 8, 17),
        note: 'Zero test',
      );

      await provider.recordMoneyOut(
        account: 'Cash',
        amount: -50.0,
        date: DateTime(2026, 8, 17),
        note: 'Negative test',
      );

      expect(provider.balances.cash, 0.0);
      expect(provider.transactions.isEmpty, true);
    });

    test('Handles micro-decimal and high precision amounts without crashing', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 0.001,
        date: DateTime(2026, 8, 17),
        note: 'Micro float',
      );

      expect(provider.balances.cash, closeTo(0.001, 0.00001));
    });

    test('Handles negative overall account balances gracefully when overdrawing', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.recordMoneyOut(
        account: 'Cash',
        amount: 150.0,
        date: DateTime(2026, 8, 17),
        note: 'Overdraft',
      );

      expect(provider.balances.cash, -150.0);
      expect(provider.balances.totalLiquid, -150.0);
    });

    test('updateAccountField with unrecognized field name is safely ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;

      await provider.updateAccountField('CryptoWallet', 1000.0);

      expect(provider.transactions.isEmpty, true);
    });
  });

  group('Group 6: Export & Persistence Integration Tests', () {
    test('FinanceCsv.encode exports summary and transactions correctly', () {
      final balances = AccountBalances(
        cash: 100.0,
        vcb: 200.0,
        mbInvestment: 300.0,
      );
      final funds = [
        Fund(id: 'f1', name: 'Backup', amount: 50.0, createdAt: DateTime(2026, 8, 1)),
        Fund(id: 'f2', name: 'Trip, Japan', amount: 25.5, createdAt: DateTime(2026, 8, 2)),
      ];

      final transactions = [
        FinanceTransaction(
          id: '1',
          type: TransactionType.moneyIn,
          account: 'Cash',
          amount: 100.0,
          date: DateTime(2026, 8, 17),
          note: 'Salary',
          previousValue: 0.0,
          newValue: 100.0,
        ),
      ];

      final csvString = FinanceCsv.encode(balances, transactions, funds);
      final summary = csvString.split('--- TRANSACTIONS LOG ---').first.trim().split('\n');

      expect(summary, [
        '--- ACCOUNT BALANCES SUMMARY ---',
        'Account,Amount (k VND),Amount (VND)',
        'Cash,100.0,100000',
        'VCB,200.0,200000',
        'MB,0.0,0',
        'Techcombank,0.0,0',
        'MB investment,300.0,300000',
        'Total Money,600.0,600000',
        'Fund: Backup,50.0,50000',
        '"Fund: Trip, Japan",25.5,25500',
        'Funds total,75.5,75500',
        'Money Left,524.5,524500',
      ]);
      expect(csvString.contains('MB fund'), false);
      expect(csvString.contains('Backup Fund'), false);
      expect(csvString.contains('--- TRANSACTIONS LOG ---'), true);
      expect(csvString.contains('moneyIn'), true);
    });

    test('SharedPreferences persistence loads saved state into new provider instance', () async {
      SharedPreferences.setMockInitialValues({});

      final firstProvider = FinanceProvider();
      await firstProvider.ready;
      await firstProvider.recordMoneyIn(
        account: 'VCB',
        amount: 750.0,
        date: DateTime(2026, 8, 17),
        note: 'Project payout',
      );

      // Create new provider instance reading from same SharedPreferences
      final secondProvider = FinanceProvider();
      await secondProvider.ready;

      expect(secondProvider.balances.vcb, 750.0);
      expect(secondProvider.transactions.length, 1);
      expect(secondProvider.transactions.first.note, 'Project payout');
    });

    test('the CSV export built from the provider leaves Trash out', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();
      await provider.ready;
      await provider.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime(2026, 8, 1), note: 'Kept');
      await provider.recordMoneyIn(account: 'Cash', amount: 20, date: DateTime(2026, 8, 2), note: 'Trashed');
      await provider.addFund(name: 'Live fund', amount: 5);
      await provider.addFund(name: 'Trashed fund', amount: 7);
      await provider.deleteTransaction(provider.transactions.first.id);
      await provider.deleteFund(provider.funds.last.id);

      final csvString = FinanceCsv.encode(provider.balances, provider.transactions, provider.funds);

      expect(csvString.contains('Kept'), true);
      expect(csvString.contains('Fund: Live fund,5.0,5000'), true);
      expect(csvString.contains('Trashed'), false);
      expect(csvString.contains('Money Left,5.0,5000'), true);
    });
  });
}
