import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../screens/money_transaction_screen.dart';
import 'finance_transaction_tile.dart';
import 'swipe_to_delete.dart';

/// A transaction tile that opens edit on tap and moves the transaction to
/// Trash on a confirmed swipe left.
class DeletableTransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;

  const DeletableTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return SwipeToDelete(
      key: ValueKey('transaction-${transaction.id}'),
      title: 'Delete transaction?',
      message: 'It will be moved to Trash, and its effect on ${transaction.account} undone. '
          'You can restore it from Trash for ${FinanceProvider.trashRetention.inDays} days.',
      onDelete: () => context.read<FinanceProvider>().deleteTransaction(transaction.id),
      child: FinanceTransactionTile(
        transaction: transaction,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => MoneyTransactionScreen(
              isMoneyIn: transaction.type == TransactionType.moneyIn,
              existingTransaction: transaction,
            ),
          ),
        ),
      ),
    );
  }
}
