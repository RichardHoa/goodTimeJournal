import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/account_icon.dart';
import '../widgets/finance_transaction_tile.dart';
import '../widgets/swipe_to_delete.dart';

/// Deleted transactions and Funds, kept for 30 days and restorable.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static final DateFormat _dateFormatter = DateFormat('MMM dd, yyyy HH:mm');

  Future<void> _restore(BuildContext context, TrashItem item) async {
    final error = await context.read<FinanceProvider>().restoreFromTrash(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error ?? 'Restored'),
        backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _deleteForever(BuildContext context, TrashItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete forever?',
      message: 'This item will be removed for good. This can\'t be undone.',
      confirmLabel: 'Delete forever',
    );
    if (confirmed && context.mounted) {
      await context.read<FinanceProvider>().deleteForever(item.id);
    }
  }

  Future<void> _emptyTrash(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Empty trash?',
      message: 'Everything in Trash will be removed for good. This can\'t be undone.',
      confirmLabel: 'Empty trash',
    );
    if (confirmed && context.mounted) {
      await context.read<FinanceProvider>().emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final provider = Provider.of<FinanceProvider>(context);
    final trash = provider.trash;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Trash', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        actions: [
          TextButton(
            onPressed: trash.isEmpty ? null : () => _emptyTrash(context),
            child: const Text('Empty trash'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: trash.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 48, color: muted),
                    const SizedBox(height: 12),
                    const Text('Trash is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Deleted transactions and Funds stay here for '
                      '${FinanceProvider.trashRetention.inDays} days.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trash.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = trash[i];
                final daysLeft = provider.daysLeftInTrash(item);
                return _TrashTile(
                  key: ValueKey(item.id),
                  item: item,
                  deletedInfo: 'Deleted ${_dateFormatter.format(item.deletedAt)} · '
                      '${daysLeft == 1 ? '1 day' : '$daysLeft days'} left',
                  onRestore: () => _restore(context, item),
                  onDeleteForever: () => _deleteForever(context, item),
                );
              },
            ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  final TrashItem item;
  final String deletedInfo;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashTile({
    super.key,
    required this.item,
    required this.deletedInfo,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final Widget icon;
    final String kindLabel;
    final String title;
    final String? note;
    switch (item.kind) {
      case TrashKind.transaction:
        final tx = item.transaction!;
        icon = AccountIcon(tx.account, size: 22);
        kindLabel = switch (tx.type) {
          TransactionType.moneyIn => 'Money In',
          TransactionType.moneyOut => 'Money Out',
          TransactionType.fieldUpdate => 'Balance update',
        };
        title = '${tx.account} · ${FinanceTransactionTile.formatVnd(tx.amount)}';
        note = '${tx.note.isEmpty ? '' : '${tx.note} · '}${tx.formattedDate}';
      case TrashKind.fund:
        final fund = item.fund!;
        icon = Icon(Icons.savings_outlined, size: 22, color: theme.colorScheme.primary);
        kindLabel = 'Fund';
        title = '${fund.name} · ${FinanceTransactionTile.formatVnd(fund.amount)}';
        note = null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kindLabel,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    Text(deletedInfo, style: TextStyle(fontSize: 11.5, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDeleteForever,
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Delete forever'),
              ),
              TextButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
