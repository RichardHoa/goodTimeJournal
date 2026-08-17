import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';
import '../utils/date_presets.dart';
import '../widgets/account_icon.dart';
import '../widgets/deletable_transaction_tile.dart';

enum TypeFilterType { all, moneyIn, moneyOut, update }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DatePreset _datePreset = DatePreset.allTime;
  /// A picked range; when set it replaces [_datePreset].
  DateTimeRange? _customDateRange;
  TypeFilterType _typeFilter = TypeFilterType.all;
  String _selectedAccount = 'All Accounts';
  
  final List<String> _accountOptions = ['All Accounts', ...FinanceProvider.liquidAccounts, FinanceProvider.mbInvestment];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = wholeDays(picked.start, picked.end);
      });
    }
  }

  bool get _hasDateFilter => _customDateRange != null || _datePreset != DatePreset.allTime;

  String get _dateFilterLabel {
    final custom = _customDateRange;
    if (custom == null) return _datePreset.label;
    final format = DateFormat('dd/MM');
    return '${format.format(custom.start)} – ${format.format(custom.end)}';
  }

  Future<void> _openDateFilterSheet() async {
    final theme = Theme.of(context);
    Widget option(String label, bool selected, VoidCallback onTap) {
      return ListTile(
        title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
        trailing: selected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
        onTap: onTap,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in DatePreset.values)
              option(preset.label, _customDateRange == null && _datePreset == preset, () {
                setState(() {
                  _datePreset = preset;
                  _customDateRange = null;
                });
                Navigator.of(sheetContext).pop();
              }),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(
                _customDateRange == null ? 'Pick range…' : 'Pick range… ($_dateFilterLabel)',
                style: TextStyle(fontWeight: _customDateRange != null ? FontWeight.bold : FontWeight.w500),
              ),
              trailing: _customDateRange != null ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _selectCustomDateRange();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<FinanceTransaction> _filterTransactions(List<FinanceTransaction> all) {
    final query = _searchController.text.trim().toLowerCase();
    final dateRange = _customDateRange ?? _datePreset.rangeFor(DateTime.now());

    return all.where((t) {
      // 1. Search Query Filter
      if (query.isNotEmpty) {
        final noteMatch = t.note.toLowerCase().contains(query);
        final accountMatch = t.account.toLowerCase().contains(query);
        final amountMatch = t.amount.toString().contains(query);
        if (!noteMatch && !accountMatch && !amountMatch) return false;
      }

      // 2. Type Filter
      if (_typeFilter == TypeFilterType.moneyIn && t.type != TransactionType.moneyIn) return false;
      if (_typeFilter == TypeFilterType.moneyOut && t.type != TransactionType.moneyOut) return false;
      if (_typeFilter == TypeFilterType.update && !t.isBalanceUpdate) return false;

      // 3. Account Filter
      if (_selectedAccount != 'All Accounts' && t.account != _selectedAccount) return false;

      // 4. Date Range Filter
      if (dateRange != null && (t.date.isBefore(dateRange.start) || t.date.isAfter(dateRange.end))) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<FinanceProvider>(context);
    final filtered = _filterTransactions(provider.transactions);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by note, account or amount...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Header Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: isDark ? AppTheme.darkBg : Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 1. Type Filter Dropdown
                  PopupMenuButton<TypeFilterType>(
                    initialValue: _typeFilter,
                    onSelected: (val) => setState(() => _typeFilter = val),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: _FilterPill(
                      label: _getTypeFilterLabel(_typeFilter),
                      icon: Icons.filter_list_rounded,
                      isSelected: _typeFilter != TypeFilterType.all,
                      hasDropdownArrow: true,
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: TypeFilterType.all, child: Text('All Types')),
                      const PopupMenuItem(value: TypeFilterType.moneyIn, child: Text('Money In (+)')),
                      const PopupMenuItem(value: TypeFilterType.moneyOut, child: Text('Money Out (-)')),
                      const PopupMenuItem(value: TypeFilterType.update, child: Text('Balance updates (MB investment)')),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // 2. Account Filter Dropdown
                  PopupMenuButton<String>(
                    initialValue: _selectedAccount,
                    onSelected: (val) => setState(() => _selectedAccount = val),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: _FilterPill(
                      label: _selectedAccount,
                      icon: Icons.account_balance_wallet_outlined,
                      leading: _selectedAccount == 'All Accounts' ? null : AccountIcon(_selectedAccount, size: 16),
                      isSelected: _selectedAccount != 'All Accounts',
                      hasDropdownArrow: true,
                    ),
                    itemBuilder: (ctx) => _accountOptions.map((acc) {
                      return PopupMenuItem(
                        value: acc,
                        child: Row(
                          children: [
                            if (acc == 'All Accounts')
                              const Icon(Icons.account_balance_wallet_outlined, size: 20)
                            else
                              AccountIcon(acc, size: 20),
                            const SizedBox(width: 10),
                            Text(acc),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),

                  // 3. Date Filter: one pill opening the presets sheet
                  GestureDetector(
                    onTap: _openDateFilterSheet,
                    child: _FilterPill(
                      label: _dateFilterLabel,
                      icon: Icons.calendar_month_rounded,
                      isSelected: _hasDateFilter,
                      hasDropdownArrow: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Count bar & Reset filters button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filtered.length} of ${provider.transactions.length} records',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                if (_typeFilter != TypeFilterType.all ||
                    _selectedAccount != 'All Accounts' ||
                    _hasDateFilter ||
                    _searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                        _typeFilter = TypeFilterType.all;
                        _selectedAccount = 'All Accounts';
                        _datePreset = DatePreset.allTime;
                        _customDateRange = null;
                      });
                    },
                    child: Text(
                      'Reset Filters',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Transaction List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching transactions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your search or date filter.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final t = filtered[i];
                      return DeletableTransactionTile(key: ValueKey(t.id), transaction: t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getTypeFilterLabel(TypeFilterType type) {
    switch (type) {
      case TypeFilterType.all: return 'All Types';
      case TypeFilterType.moneyIn: return 'Money In';
      case TypeFilterType.moneyOut: return 'Money Out';
      case TypeFilterType.update: return 'Updates';
    }
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  /// Shown instead of [icon] when given.
  final Widget? leading;
  final bool isSelected;
  final bool hasDropdownArrow;

  const _FilterPill({
    required this.label,
    this.icon,
    this.leading,
    this.isSelected = false,
    this.hasDropdownArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isSelected
        ? theme.colorScheme.primary
        : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface);

    final foregroundColor = isSelected
        ? (isDark ? const Color(0xFF0D0B14) : Colors.white)
        : theme.textTheme.bodyMedium?.color;

    final borderColor = isSelected
        ? theme.colorScheme.primary
        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      height: 38,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null || icon != null) ...[
            leading ?? Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: foregroundColor,
            ),
          ),
          if (hasDropdownArrow) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: foregroundColor),
          ],
        ],
      ),
    );
  }
}

