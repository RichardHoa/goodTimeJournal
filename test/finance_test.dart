import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/services/csv_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: AccountBalances & FinanceTransaction Model Unit Tests', () {
    test('AccountBalances totalMoney, totalLiquid, and moneyLeft calculations', () {
      final balances = AccountBalances(
        cash: 100.0,
        vcb: 200.0,
        mb: 300.0,
        techcombank: 400.0,
        mbFund: 500.0,
        backupFund: 250.0,
      );

      expect(balances.totalLiquid, 1000.0);
      expect(balances.totalMoney, 1500.0);
      expect(balances.moneyLeft, 1250.0);
    });

    test('AccountBalances copyWith updates specified fields only', () {
      final initial = AccountBalances(cash: 50.0, vcb: 100.0);
      final updated = initial.copyWith(cash: 75.0, backupFund: 20.0);

      expect(updated.cash, 75.0);
      expect(updated.vcb, 100.0);
      expect(updated.backupFund, 20.0);
    });

    test('AccountBalances toJson and fromJson fidelity (handles ints & double values)', () {
      final json = {
        'cash': 100, // integer input
        'vcb': 200.55,
        'mb': 300,
        'techcombank': 400.0,
        'mbFund': 500,
        'backupFund': 250.25,
      };

      final balances = AccountBalances.fromJson(json);
      expect(balances.cash, 100.0);
      expect(balances.vcb, 200.55);
      expect(balances.backupFund, 250.25);

      final exportedJson = balances.toJson();
      expect(exportedJson['cash'], 100.0);
      expect(exportedJson['backupFund'], 250.25);
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

    test('updateAccountField updates liquid accounts and reserve funds', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

      await provider.updateAccountField('Cash', 250.0);
      await provider.updateAccountField('MB fund', 1000.0);
      await provider.updateAccountField('Backup Fund', 300.0);

      expect(provider.balances.cash, 250.0);
      expect(provider.balances.mbFund, 1000.0);
      expect(provider.balances.backupFund, 300.0);
      expect(provider.balances.totalMoney, 1250.0);
      expect(provider.balances.moneyLeft, 950.0);
      expect(provider.transactions.length, 3);
    });
  });

  group('Group 3: Transaction Deletion & Reversion Tests', () {
    test('deleteTransaction reverts moneyIn correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

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

    test('deleteTransaction reverts fieldUpdate correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

      await provider.updateAccountField('VCB', 100.0);
      await provider.updateAccountField('VCB', 300.0);
      expect(provider.balances.vcb, 300.0);

      final secondFieldTxId = provider.transactions.first.id;
      await provider.deleteTransaction(secondFieldTxId);

      expect(provider.balances.vcb, 100.0);
    });

    test('deleteTransaction on non-existent ID does not mutate state', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

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
    test('recordMoneyIn and recordMoneyOut ignore reserve funds (MB fund, Backup Fund)', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

      await provider.recordMoneyIn(
        account: 'MB fund',
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

      expect(provider.balances.mbFund, 0.0);
      expect(provider.balances.backupFund, 0.0);
      expect(provider.transactions.isEmpty, true);
    });

    test('recordMoneyIn and recordMoneyOut ignore non-positive amounts (amount <= 0)', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

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

      await provider.updateAccountField('CryptoWallet', 1000.0);

      expect(provider.transactions.isEmpty, true);
    });
  });

  group('Group 6: Export & Persistence Integration Tests', () {
    test('CsvService.exportFinanceToCsv exports summary and transactions correctly', () {
      final balances = AccountBalances(
        cash: 100.0,
        vcb: 200.0,
        backupFund: 50.0,
      );

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

      final csvString = CsvService.exportFinanceToCsv(balances, transactions);

      expect(csvString.contains('--- ACCOUNT BALANCES SUMMARY ---'), true);
      expect(csvString.contains('Cash,100.0,100000'), true);
      expect(csvString.contains('Backup Fund,50.0,50000'), true);
      expect(csvString.contains('--- TRANSACTIONS LOG ---'), true);
      expect(csvString.contains('moneyIn'), true);
    });

    test('SharedPreferences persistence loads saved state into new provider instance', () async {
      SharedPreferences.setMockInitialValues({});

      final firstProvider = FinanceProvider();
      await firstProvider.recordMoneyIn(
        account: 'VCB',
        amount: 750.0,
        date: DateTime(2026, 8, 17),
        note: 'Project payout',
      );

      // Create new provider instance reading from same SharedPreferences
      final secondProvider = FinanceProvider();
      // Allow async microtask/load to process
      await Future.delayed(const Duration(milliseconds: 50));

      expect(secondProvider.balances.vcb, 750.0);
      expect(secondProvider.transactions.length, 1);
      expect(secondProvider.transactions.first.note, 'Project payout');
    });
  });
}
