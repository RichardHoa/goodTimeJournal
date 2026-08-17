import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';

/// Reusable, performance-optimized transaction tile for feed and history lists.
class FinanceTransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static final DateFormat _dateFormatter = DateFormat('MMM dd, yyyy HH:mm');
  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'en_US');

  const FinanceTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  static String formatVnd(double kValue) {
    final double fullVnd = kValue * 1000;
    return '${_currencyFormatter.format(fullVnd)} VND';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isIncome = transaction.type == TransactionType.moneyIn;
    final isExpense = transaction.type == TransactionType.moneyOut;

    IconData iconData = Icons.edit_note_rounded;
    Color itemColor = theme.colorScheme.primary;

    if (isIncome) {
      iconData = Icons.arrow_downward_rounded;
      itemColor = theme.colorScheme.primary;
    } else if (isExpense) {
      iconData = Icons.arrow_upward_rounded;
      itemColor = theme.colorScheme.secondary;
    }

    final dateStr = _dateFormatter.format(transaction.date);
    final formattedAmount = formatVnd(transaction.amount);

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              color: itemColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        transaction.account,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isIncome ? 'Money In' : (isExpense ? 'Money Out' : 'Update'),
                        style: TextStyle(
                          color: itemColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (transaction.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isIncome ? '+' : (isExpense ? '-' : '')}$formattedAmount',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: itemColor,
                  ),
                ),
              ),
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit transaction',
                        onPressed: onEdit,
                      ),
                    if (onEdit != null && onDelete != null) const SizedBox(width: 12),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Delete transaction',
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
