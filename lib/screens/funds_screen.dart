import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_input.dart';
import '../widgets/finance_transaction_tile.dart';
import '../widgets/swipe_to_delete.dart';

/// Every Fund, in creation order: add, tap to edit, swipe left to delete.
class FundsScreen extends StatelessWidget {
  const FundsScreen({super.key});

  void _openFundDialog(BuildContext context, {Fund? fund}) {
    showDialog(context: context, builder: (ctx) => _FundDialog(fund: fund));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final provider = Provider.of<FinanceProvider>(context);
    final funds = provider.funds;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Funds', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFundDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add fund'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightPrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set aside in Funds', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted)),
                const SizedBox(height: 4),
                Text(
                  FinanceTransactionTile.formatVnd(provider.fundsTotal),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'Money Left: ${FinanceTransactionTile.formatVnd(provider.moneyLeft)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: provider.moneyLeft < 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Money ${FinanceTransactionTile.formatVnd(provider.balances.totalMoney)} − Funds',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (funds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No Funds yet. Tap "Add fund" to set money aside for a purpose.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            )
          else ...[
            Text('Tap to edit · swipe left to delete', style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 10),
            for (final fund in funds) ...[
              SwipeToDelete(
                key: ValueKey('fund-${fund.id}'),
                title: 'Delete "${fund.name}"?',
                message: 'It will be moved to Trash. '
                    'You can restore it from Trash for ${FinanceProvider.trashRetention.inDays} days.',
                onDelete: () => context.read<FinanceProvider>().deleteFund(fund.id),
                child: _FundRow(fund: fund, onTap: () => _openFundDialog(context, fund: fund)),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _FundRow extends StatelessWidget {
  final Fund fund;
  final VoidCallback onTap;

  const _FundRow({required this.fund, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.savings_outlined, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  fund.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                FinanceTransactionTile.formatVnd(fund.amount),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add a Fund, or edit [fund] when given.
class _FundDialog extends StatefulWidget {
  final Fund? fund;

  const _FundDialog({this.fund});

  @override
  State<_FundDialog> createState() => _FundDialogState();
}

class _FundDialogState extends State<_FundDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String? _nameError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fund?.name ?? '');
    final amount = widget.fund?.amount;
    _amountController = TextEditingController(
      text: amount == null ? '' : amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<FinanceProvider>();
    final name = _nameController.text;
    final amount = parseAmountK(_amountController.text);

    final nameError = provider.validateFundName(name, exceptId: widget.fund?.id);
    final amountError = amount == null || amount < 0 ? 'Please enter a valid positive number' : null;
    if (nameError != null || amountError != null) {
      setState(() {
        _nameError = nameError;
        _amountError = amountError;
      });
      return;
    }

    final fund = widget.fund;
    final error = fund == null
        ? await provider.addFund(name: name, amount: amount!)
        : await provider.updateFund(fund.id, name: name, amount: amount!);
    if (!mounted) return;
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.fund != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEditing ? 'Edit fund' : 'Add fund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Name, e.g. Travel', errorText: _nameError),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: amountInputDecoration(context, text: _amountController.text, errorText: _amountError),
            onChanged: (_) => setState(() => _amountError = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
