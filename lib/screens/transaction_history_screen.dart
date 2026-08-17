import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';
import '../widgets/money_transaction_modal.dart';
import '../widgets/finance_transaction_tile.dart';

enum DateFilterType { allTime, today, thisWeek, thisMonth, custom }
enum TypeFilterType { all, moneyIn, moneyOut, update }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateFilterType _dateFilter = DateFilterType.allTime;
  DateTimeRange? _customDateRange;
  TypeFilterType _typeFilter = TypeFilterType.all;
  String _selectedAccount = 'All Accounts';
  
  final List<String> _accountOptions = ['All Accounts', 'Cash', 'VCB', 'MB', 'Techcombank', 'MB fund', 'Backup Fund'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditModal(BuildContext context, FinanceTransaction transaction) {
    showDialog(
      context: context,
      builder: (ctx) => MoneyTransactionModal(
        isMoneyIn: transaction.type == TransactionType.moneyIn,
        existingTransaction: transaction,
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.deleteTransaction(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        _customDateRange = picked;
        _dateFilter = DateFilterType.custom;
      });
    }
  }

  List<FinanceTransaction> _filterTransactions(List<FinanceTransaction> all) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

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
      if (_typeFilter == TypeFilterType.update && t.type != TransactionType.fieldUpdate) return false;

      // 3. Account Filter
      if (_selectedAccount != 'All Accounts' && t.account != _selectedAccount) return false;

      // 4. Date Range Filter
      if (_dateFilter == DateFilterType.today) {
        final isSameDay = t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
        if (!isSameDay) return false;
      } else if (_dateFilter == DateFilterType.thisWeek) {
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        if (t.date.isBefore(sevenDaysAgo)) return false;
      } else if (_dateFilter == DateFilterType.thisMonth) {
        if (t.date.year != now.year || t.date.month != now.month) return false;
      } else if (_dateFilter == DateFilterType.custom && _customDateRange != null) {
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
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
                      const PopupMenuItem(value: TypeFilterType.update, child: Text('Field Updates')),
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
                      isSelected: _selectedAccount != 'All Accounts',
                      hasDropdownArrow: true,
                    ),
                    itemBuilder: (ctx) => _accountOptions.map((acc) {
                      return PopupMenuItem(value: acc, child: Text(acc));
                    }).toList(),
                  ),
                  const SizedBox(width: 8),

                  // 3. Date Range Filter Quick Pills
                  _buildDateFilterPill(DateFilterType.allTime, 'All Time'),
                  const SizedBox(width: 8),
                  _buildDateFilterPill(DateFilterType.today, 'Today'),
                  const SizedBox(width: 8),
                  _buildDateFilterPill(DateFilterType.thisWeek, 'This Week'),
                  const SizedBox(width: 8),
                  _buildDateFilterPill(DateFilterType.thisMonth, 'This Month'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _selectCustomDateRange,
                    child: _FilterPill(
                      label: _dateFilter == DateFilterType.custom && _customDateRange != null
                          ? '${DateFormat('MM/dd').format(_customDateRange!.start)} - ${DateFormat('MM/dd').format(_customDateRange!.end)}'
                          : 'Custom Date',
                      icon: Icons.calendar_month_rounded,
                      isSelected: _dateFilter == DateFilterType.custom,
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
                    _dateFilter != DateFilterType.allTime ||
                    _searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                        _typeFilter = TypeFilterType.all;
                        _selectedAccount = 'All Accounts';
                        _dateFilter = DateFilterType.allTime;
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
                      return FinanceTransactionTile(
                        transaction: t,
                        onEdit: () => _openEditModal(context, t),
                        onDelete: () => _confirmDelete(context, provider, t.id),
                      );
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

  Widget _buildDateFilterPill(DateFilterType type, String label) {
    final isSelected = _dateFilter == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _dateFilter = type;
          _customDateRange = null;
        });
      },
      child: _FilterPill(
        label: label,
        isSelected: isSelected,
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool hasDropdownArrow;

  const _FilterPill({
    required this.label,
    this.icon,
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
          if (icon != null) ...[
            Icon(icon, size: 16, color: foregroundColor),
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

