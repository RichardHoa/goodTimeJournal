import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_presets.dart';
import '../utils/history_filter.dart';
import '../widgets/account_icon.dart';

/// Pick what the transaction history shows: type, account, Category and
/// date. Pops with the new [HistoryFilter] on Apply; Back keeps the old one.
class HistoryFiltersScreen extends StatefulWidget {
  final HistoryFilter initial;
  /// How many records a filter would show, for the Apply button.
  final int Function(HistoryFilter filter) countFor;

  const HistoryFiltersScreen({super.key, required this.initial, required this.countFor});

  @override
  State<HistoryFiltersScreen> createState() => _HistoryFiltersScreenState();
}

class _HistoryFiltersScreenState extends State<HistoryFiltersScreen> {
  late HistoryFilter _filter = widget.initial;

  static const List<String> _accounts = [...FinanceProvider.liquidAccounts, FinanceProvider.mbInvestment];

  Set<T> _toggled<T>(Set<T> set, T value) => set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _filter.customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null && mounted) {
      setState(() => _filter = _filter.copyWith(customRange: () => wholeDays(picked.start, picked.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final provider = context.watch<FinanceProvider>();
    final count = widget.countFor(_filter);

    Widget section(String title, {String? hint, required List<Widget> children}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (hint != null) Text(hint, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 8),
            // Material, not a decorated box, so the tiles' ink shows.
            Material(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ],
        ),
      );
    }

    Widget check(String label, bool value, VoidCallback onTap, {Widget? leading}) {
      return CheckboxListTile(
        value: value,
        onChanged: (_) => setState(onTap),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        secondary: leading,
        dense: true,
        controlAffinity: ListTileControlAffinity.trailing,
      );
    }

    Widget categoryGroup(TransactionType type, String title) {
      final categories = provider.categoriesFor(type);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
          ),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text('No categories yet', style: TextStyle(fontSize: 13, color: muted)),
            ),
          for (final c in categories)
            check(c.name, _filter.categoryIds.contains(c.id),
                () => _filter = _filter.copyWith(categoryIds: _toggled(_filter.categoryIds, c.id))),
        ],
      );
    }

    final custom = _filter.customRange;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close without applying',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _filter.activeCount == 0 ? null : () => setState(() => _filter = const HistoryFilter()),
            child: const Text('Reset'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          section('Date', children: [
            for (final preset in DatePreset.values)
              ListTile(
                dense: true,
                title: Text(preset.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: custom == null && _filter.datePreset == preset
                    ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () => setState(() => _filter = _filter.copyWith(datePreset: preset, customRange: () => null)),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(
                custom == null
                    ? 'Custom range…'
                    : '${dateFormat.format(custom.start)} – ${dateFormat.format(custom.end)}',
                style: TextStyle(fontWeight: custom != null ? FontWeight.w800 : FontWeight.w600),
              ),
              trailing: custom != null ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: _pickCustomRange,
            ),
          ]),
          section('Type', hint: 'None ticked: all', children: [
            for (final type in HistoryType.values)
              check(type.label, _filter.types.contains(type),
                  () => _filter = _filter.copyWith(types: _toggled(_filter.types, type))),
          ]),
          section('Category', hint: 'None ticked: all', children: [
            check('Uncategorized', _filter.categoryIds.contains(null),
                () => _filter = _filter.copyWith(categoryIds: _toggled(_filter.categoryIds, null))),
            const Divider(height: 1),
            categoryGroup(TransactionType.moneyOut, 'MONEY OUT'),
            const Divider(height: 1),
            categoryGroup(TransactionType.moneyIn, 'MONEY IN'),
          ]),
          section('Account', hint: 'None ticked: all', children: [
            for (final account in _accounts)
              check(account, _filter.accounts.contains(account),
                  () => _filter = _filter.copyWith(accounts: _toggled(_filter.accounts, account)),
                  leading: AccountIcon(account, size: 22)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.of(context).pop(_filter),
            child: Text('Show ${count == 1 ? '1 record' : '$count records'}'),
          ),
        ),
      ),
    );
  }
}
