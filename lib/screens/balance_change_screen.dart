import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/amounts.dart';
import '../widgets/account_icon.dart';
import '../widgets/amount_input.dart';
import '../widgets/category_picker.dart';

/// Explain a direct edit to a Liquid account's balance with Money In or
/// Money Out entries; whatever is left unexplained becomes a Balance
/// adjustment. Leaving without saving changes nothing.
class BalanceChangeScreen extends StatefulWidget {
  final String account;
  final double newBalance;

  const BalanceChangeScreen({super.key, required this.account, required this.newBalance});

  @override
  State<BalanceChangeScreen> createState() => _BalanceChangeScreenState();
}

class _Entry {
  final TextEditingController amount = TextEditingController();
  final TextEditingController note = TextEditingController();
  DateTime date = DateTime.now();
  String? categoryId;

  /// Blank entries are skipped on save.
  bool get isBlank => amount.text.trim().isEmpty && note.text.trim().isEmpty;

  void dispose() {
    amount.dispose();
    note.dispose();
  }
}

class _BalanceChangeScreenState extends State<BalanceChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_Entry> _entries = [];
  late final double _oldBalance;

  @override
  void initState() {
    super.initState();
    _oldBalance = context.read<FinanceProvider>().balances.of(widget.account);
    _addEntry();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  double get _change => roundAmount(widget.newBalance - _oldBalance);
  bool get _isRise => _change > 0;
  TransactionType get _type => _isRise ? TransactionType.moneyIn : TransactionType.moneyOut;

  double get _explained {
    var sum = 0.0;
    for (final e in _entries) {
      final v = parseAmountK(e.amount.text);
      if (v != null && v > 0) sum += v;
    }
    return roundAmount(sum);
  }

  void _addEntry() {
    final entry = _Entry();
    entry.amount.addListener(_rebuild);
    setState(() => _entries.add(entry));
  }

  void _removeEntry(_Entry entry) {
    setState(() => _entries.remove(entry));
    // Its fields still listen to the controllers until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  void _rebuild() => setState(() {});

  Future<void> _pickDate(_Entry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => entry.date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final over = roundAmount(_explained - _change.abs());
    if (over > 0) {
      final endsAt = roundAmount(_oldBalance + (_isRise ? _explained : -_explained));
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Entries add up to more than the change'),
          content: Text(
            'They are ${formatVnd(over)} over. Saving records them as typed, so '
            '${widget.account} will end at ${formatVnd(endsAt)}, not ${formatVnd(widget.newBalance)}.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save anyway')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final entries = [
      for (final e in _entries)
        if (!e.isBlank)
          BalanceChangeEntry(
            amount: parseAmountK(e.amount.text)!,
            note: e.note.text,
            date: e.date,
            categoryId: e.categoryId,
          ),
    ];
    await context.read<FinanceProvider>().explainBalanceChange(
          account: widget.account,
          newBalance: widget.newBalance,
          entries: entries,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final flowColor = _isRise
        ? (isDark ? AppTheme.darkMoneyIn : AppTheme.lightMoneyIn)
        : (isDark ? AppTheme.darkMoneyOut : AppTheme.lightMoneyOut);
    final direction = _isRise ? 'Money In' : 'Money Out';
    final remaining = roundAmount(_change.abs() - _explained);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel: keep the balance as it was',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Explain ${widget.account} change', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: flowColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: flowColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  AccountIcon(widget.account, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatVnd(_oldBalance)} → ${formatVnd(widget.newBalance)}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$direction to explain: ${formatVnd(_change.abs())}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: flowColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a $direction for each reason. Anything left unexplained is saved as one '
              '"${FinanceProvider.balanceAdjustmentNote}".',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 16),
            for (final (i, entry) in _entries.indexed) ...[
              _buildEntry(context, i, entry, muted),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add $direction entry'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(remaining < 0 ? 'Over by' : 'Left to explain', style: TextStyle(fontSize: 12, color: muted)),
                    Text(
                      formatVnd(remaining.abs()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: remaining < 0 ? theme.colorScheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, int index, _Entry entry, Color muted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Entry ${index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove entry',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () => _removeEntry(entry),
              ),
            ],
          ),
          AmountField(
            controller: entry.amount,
            // A blank entry is skipped; any other needs a valid amount.
            validator: (text) => entry.isBlank ? null : validateAmountText(text),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: entry.note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Reason, e.g. Lunch'),
          ),
          const SizedBox(height: 10),
          CategoryPicker(
            type: _type,
            value: entry.categoryId,
            onChanged: (id) => setState(() => entry.categoryId = id),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _pickDate(entry),
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
              ),
              child: Text(DateFormat('yyyy-MM-dd').format(entry.date)),
            ),
          ),
        ],
      ),
    );
  }
}
