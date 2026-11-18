import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';
import '../utils/amounts.dart';
import '../utils/history_filter.dart';
import '../widgets/deletable_transaction_tile.dart';
import 'history_filters_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  /// Kept while the app runs, so leaving and reopening history keeps the
  /// filter; a restart resets it.
  static HistoryFilter _lastFilter = const HistoryFilter();

  final TextEditingController _searchController = TextEditingController();
  HistoryFilter _filter = _lastFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static final ButtonStyle _filterButtonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );

  void _setFilter(HistoryFilter filter) {
    setState(() => _filter = filter);
    _lastFilter = filter;
  }

  Map<String, String> _categoryNames(FinanceProvider provider) => {for (final c in provider.categories) c.id: c.name};

  List<FinanceTransaction> _apply(FinanceProvider provider, HistoryFilter filter) {
    final now = DateTime.now();
    final names = _categoryNames(provider);
    return provider.transactions
        .where((t) => filter.matches(t, now: now, query: _searchController.text, categoryNames: names))
        .toList();
  }

  Future<void> _openFilters(FinanceProvider provider) async {
    final picked = await Navigator.of(context).push<HistoryFilter>(
      MaterialPageRoute(
        builder: (ctx) => HistoryFiltersScreen(
          initial: _filter,
          countFor: (filter) => _apply(provider, filter).length,
        ),
      ),
    );
    if (picked != null && mounted) _setFilter(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final provider = Provider.of<FinanceProvider>(context);
    final filtered = _apply(provider, _filter);
    final activeCount = _filter.activeCount;

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search note, account, category…',
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
                const SizedBox(width: 10),
                // The theme gives buttons infinite min width; in a Row that
                // fails layout and the button never draws.
                SizedBox(
                  height: 48,
                  child: activeCount == 0
                      ? OutlinedButton.icon(
                          style: _filterButtonStyle,
                          onPressed: () => _openFilters(provider),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Filters'),
                        )
                      : FilledButton.icon(
                          style: _filterButtonStyle,
                          onPressed: () => _openFilters(provider),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text('Filters · $activeCount'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            summary: HistorySummary.of(filtered),
            categoryNames: _categoryNames(provider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filtered.length} of ${provider.transactions.length} records',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
                if (activeCount > 0 || _searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _setFilter(const HistoryFilter());
                    },
                    child: Text(
                      'Reset Filters',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: muted),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Try adjusting your search or filters.', style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            )
          else
            for (final t in filtered) ...[
              DeletableTransactionTile(key: ValueKey(t.id), transaction: t),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// In · Out · Net for the shown records; tap to see each by Category.
class _SummaryCard extends StatefulWidget {
  final HistorySummary summary;
  final Map<String, String> categoryNames;

  const _SummaryCard({required this.summary, required this.categoryNames});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inColor = isDark ? AppTheme.darkMoneyIn : AppTheme.lightMoneyIn;
    final outColor = isDark ? AppTheme.darkMoneyOut : AppTheme.lightMoneyOut;
    final summary = widget.summary;

    Widget total(String label, String value, Color? color) {
      // The end padding keeps large shrunk totals from running together.
      return Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      );
    }

    Widget breakdown(String title, Map<String?, double> byCategory, Color color) {
      final rows = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
          const SizedBox(height: 6),
          if (rows.isEmpty) Text('Nothing', style: TextStyle(fontSize: 13, color: muted)),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.categoryNames[row.key] ?? 'Uncategorized',
                      style: TextStyle(fontSize: 13.5, fontStyle: row.key == null ? FontStyle.italic : null),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(formatVnd(row.value), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
        ],
      );
    }

    return Material(
      color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightPrimary.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  total('Money In', '+${formatVnd(summary.moneyIn)}', inColor),
                  total('Money Out', '−${formatVnd(summary.moneyOut)}', outColor),
                  total('Net', formatVnd(summary.net), null),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: muted),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                breakdown('MONEY OUT BY CATEGORY', summary.moneyOutByCategory, outColor),
                const SizedBox(height: 12),
                breakdown('MONEY IN BY CATEGORY', summary.moneyInByCategory, inColor),
              ] else ...[
                const SizedBox(height: 6),
                Text('Tap for totals by category', style: TextStyle(fontSize: 11.5, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
