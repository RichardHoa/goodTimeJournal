import 'package:flutter/material.dart';
import '../models/finance_model.dart';
import '../screens/money_transaction_screen.dart';

/// Legacy modal export redirecting to MoneyTransactionScreen
class MoneyTransactionModal extends StatelessWidget {
  final bool isMoneyIn;
  final FinanceTransaction? existingTransaction;

  const MoneyTransactionModal({
    super.key,
    required this.isMoneyIn,
    this.existingTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return MoneyTransactionScreen(
      isMoneyIn: isMoneyIn,
      existingTransaction: existingTransaction,
    );
  }
}
