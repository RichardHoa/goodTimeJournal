import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FinanceModel & FinanceProvider tests', () {
    test('AccountBalances totalMoney and moneyLeft calculations', () {
      final balances = AccountBalances(
        cash: 100.0,
        vcb: 200.0,
        mb: 300.0,
        techcombank: 400.0,
        mbFund: 500.0,
        backupFund: 250.0,
      );

      expect(balances.totalMoney, 1500.0);
      expect(balances.moneyLeft, 1250.0);
    });

    test('FinanceProvider money in and money out records correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 50.0,
        date: DateTime(2026, 8, 13),
        note: 'Freelance bonus',
      );

      expect(provider.balances.cash, 50.0);
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.note, 'Freelance bonus');
      expect(provider.transactions.first.type, TransactionType.moneyIn);

      await provider.recordMoneyOut(
        account: 'Cash',
        amount: 20.0,
        date: DateTime(2026, 8, 13),
        note: 'Groceries',
      );

      expect(provider.balances.cash, 30.0);
      expect(provider.transactions.length, 2);
      expect(provider.transactions.first.note, 'Groceries');
      expect(provider.transactions.first.type, TransactionType.moneyOut);
    });

    test('FinanceProvider deleteTransaction recalculates account balance back to previous stage', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FinanceProvider();

      await provider.recordMoneyIn(
        account: 'Cash',
        amount: 100.0,
        date: DateTime(2026, 8, 13),
        note: 'Deposit',
      );
      expect(provider.balances.cash, 100.0);

      final txId = provider.transactions.first.id;
      await provider.deleteTransaction(txId);

      expect(provider.balances.cash, 0.0);
      expect(provider.transactions.isEmpty, true);
    });
  });
}
