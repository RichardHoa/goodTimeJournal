import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';
import 'account_icon.dart';

/// Reusable, performance-optimized transaction tile for feed and history lists.
class FinanceTransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  static final DateFormat _dateFormatter = DateFormat('MMM dd, yyyy HH:mm');
  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'en_US');

  const FinanceTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  static String formatVnd(double kValue) {
    final double fullVnd = kValue * 1000;
    return '${_currencyFormatter.format(fullVnd)} VND';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Money In is blue and points into the wallet; Money Out is magenta and
    // points away from it, so direction reads at a glance even without color.
    final (iconData, itemColor, typeLabel, sign) = switch (transaction.type) {
      TransactionType.moneyIn =>
        (Icons.south_west_rounded, isDark ? AppTheme.darkMoneyIn : AppTheme.lightMoneyIn, 'Money In', '+'),
      TransactionType.moneyOut =>
        (Icons.north_east_rounded, isDark ? AppTheme.darkMoneyOut : AppTheme.lightMoneyOut, 'Money Out', '−'),
      TransactionType.fieldUpdate => (Icons.edit_note_rounded, theme.colorScheme.primary, 'Update', ''),
    };
    final isFlow = transaction.type != TransactionType.fieldUpdate;

    final dateStr = _dateFormatter.format(transaction.date);
    final formattedAmount = formatVnd(transaction.amount);

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFlow
            ? Color.alphaBlend(itemColor.withValues(alpha: isDark ? 0.07 : 0.05), theme.cardTheme.color ?? theme.colorScheme.surface)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFlow
              ? itemColor.withValues(alpha: isDark ? 0.35 : 0.3)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
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
                    AccountIcon(transaction.account, size: 16),
                    const SizedBox(width: 6),
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
                        typeLabel,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$sign$formattedAmount',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: itemColor,
              ),
            ),
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
