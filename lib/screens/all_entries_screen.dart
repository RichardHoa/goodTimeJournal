import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/journal_provider.dart';
import '../models/entry_model.dart';
import '../widgets/gauge_chart.dart';
import '../theme/app_theme.dart';
import 'add_entry_screen.dart';

enum FlowFilter { all, flowOnly, nonFlowOnly }

class AllEntriesScreen extends StatefulWidget {
  const AllEntriesScreen({super.key});

  @override
  State<AllEntriesScreen> createState() => _AllEntriesScreenState();
}

class _AllEntriesScreenState extends State<AllEntriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter States
  double _minEngagement = 0.0;
  double _minGoodness = 0.0;
  FlowFilter _flowFilter = FlowFilter.all;
  bool _showFilters = false;

  bool get _hasActiveFilters =>
      _minEngagement > 0.0 || _minGoodness > 0.0 || _flowFilter != FlowFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _minEngagement = 0.0;
      _minGoodness = 0.0;
      _flowFilter = FlowFilter.all;
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today • ${DateFormat('MMM d, yyyy').format(date)}';
    } else if (targetDate == yesterday) {
      return 'Yesterday • ${DateFormat('MMM d, yyyy').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }

  void _showCsvOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CsvImportExportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded, size: 22),
            tooltip: 'Import / Export CSV',
            onPressed: () => _showCsvOptionsModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24),
            tooltip: 'Add Entry',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEntryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search activities...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: _hasActiveFilters
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  icon: Badge(
                    isLabelVisible: _hasActiveFilters,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      _showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                      color: _hasActiveFilters ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  tooltip: 'Filter Entries',
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
              ],
            ),
          ),

          // Expanded Filter Panel
          if (_showFilters)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Options',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: _resetFilters,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 32)),
                          child: const Text('Reset All', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Flow Filter Chips
                  const Text('Flow State:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _flowFilter == FlowFilter.all,
                        onSelected: (selected) {
                          if (selected) setState(() => _flowFilter = FlowFilter.all);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('⚡ Flow Only'),
                        selected: _flowFilter == FlowFilter.flowOnly,
                        onSelected: (selected) {
                          if (selected) setState(() => _flowFilter = FlowFilter.flowOnly);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Non-Flow'),
                        selected: _flowFilter == FlowFilter.nonFlowOnly,
                        onSelected: (selected) {
                          if (selected) setState(() => _flowFilter = FlowFilter.nonFlowOnly);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Engagement Filter Slider
                  Row(
                    children: [
                      Text(
                        'Min Engagement: ${_minEngagement.toInt()}/10',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minEngagement,
                    min: 0.0,
                    max: 10.0,
                    divisions: 10,
                    label: _minEngagement.toInt().toString(),
                    onChanged: (val) {
                      setState(() {
                        _minEngagement = val;
                      });
                    },
                  ),

                  // Goodness Filter Slider
                  Row(
                    children: [
                      Text(
                        'Min Goodness: ${_minGoodness.toInt()}/10',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minGoodness,
                    min: 0.0,
                    max: 10.0,
                    divisions: 10,
                    label: _minGoodness.toInt().toString(),
                    onChanged: (val) {
                      setState(() {
                        _minGoodness = val;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Entries Grouped List
          Expanded(
            child: Consumer<JournalProvider>(
              builder: (context, provider, _) {
                final filteredEntries = provider.entries.where((entry) {
                  // Search query filter
                  if (_searchQuery.isNotEmpty &&
                      !entry.activity.toLowerCase().contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  // Engagement filter
                  if (entry.engagement < _minEngagement) {
                    return false;
                  }

                  // Goodness filter
                  if (entry.goodness < _minGoodness) {
                    return false;
                  }

                  // Flow filter
                  if (_flowFilter == FlowFilter.flowOnly && !entry.isFlow) {
                    return false;
                  }
                  if (_flowFilter == FlowFilter.nonFlowOnly && entry.isFlow) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filteredEntries.isEmpty) {
                  return _EmptyStateView(
                    searchQuery: _searchQuery,
                    hasFilters: _hasActiveFilters,
                    isDark: isDark,
                    onResetFilters: _resetFilters,
                  );
                }

                // Group entries by dateKey
                final Map<String, List<JournalEntry>> groupedMap = {};
                for (final entry in filteredEntries) {
                  final key = entry.dateKey;
                  if (!groupedMap.containsKey(key)) {
                    groupedMap[key] = [];
                  }
                  groupedMap[key]!.add(entry);
                }

                final dateKeys = groupedMap.keys.toList();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: dateKeys.length,
                  itemBuilder: (context, dateIndex) {
                    final dateKey = dateKeys[dateIndex];
                    final dayEntries = groupedMap[dateKey]!;
                    final sampleDate = dayEntries.first.timestamp;
                    final headerTitle = _formatDateHeader(sampleDate);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date Separator Header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                  thickness: 1,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkPrimaryContainer
                                      : AppTheme.lightPrimaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      headerTitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dayEntries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, entryIndex) {
                            final entry = dayEntries[entryIndex];
                            return _JournalEntryCard(
                              entry: entry,
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEntryScreen(entryToEdit: entry),
                                  ),
                                );
                              },
                              onDelete: () => provider.deleteEntry(entry.id),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  final String searchQuery;
  final bool hasFilters;
  final bool isDark;
  final VoidCallback onResetFilters;

  const _EmptyStateView({
    required this.searchQuery,
    required this.hasFilters,
    required this.isDark,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isNotEmpty || hasFilters
                  ? Icons.search_off_rounded
                  : Icons.collections_bookmark_outlined,
              size: 56,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty || hasFilters
                  ? 'No entries match your search/filters'
                  : 'No journal entries recorded',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty || hasFilters
                  ? 'Try clearing active filters or changing your search.'
                  : 'Tap "+" in the header to log your activity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormatted = DateFormat('hh:mm a').format(entry.timestamp);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: Text('Are you sure you want to delete "${entry.activity}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  minimumSize: const Size(80, 44),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        onDelete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${entry.activity}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.activity,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeFormatted,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                              ),
                            ),
                            if (entry.isFlow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      '⚡ Flow State',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Edit Entry',
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        tooltip: 'Delete Entry',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Entry'),
                              content: Text('Delete "${entry.activity}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    minimumSize: const Size(80, 44),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            onDelete();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GaugeChartWidget(
                      title: 'Engagement',
                      value: entry.engagement,
                      type: GaugeType.engagement,
                      isInteractive: false,
                      size: 120,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GaugeChartWidget(
                      title: 'Goodness',
                      value: entry.goodness,
                      type: GaugeType.goodness,
                      isInteractive: false,
                      size: 120,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet widget for CSV Import and Export
class _CsvImportExportSheet extends StatefulWidget {
  @override
  State<_CsvImportExportSheet> createState() => _CsvImportExportSheetState();
}

class _CsvImportExportSheetState extends State<_CsvImportExportSheet> {
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _exportCsvData(BuildContext context) async {
    final provider = context.read<JournalProvider>();
    final csvString = provider.exportCsv();
    final savedPath = await provider.exportAndSaveCsvToDownloads();

    Clipboard.setData(ClipboardData(text: csvString));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('CSV Exported'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (savedPath != null) ...[
              const Text(
                'Saved CSV to Downloads folder:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  savedPath,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'CSV contents also copied to clipboard:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvString,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Text'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Entries from CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste CSV content below (Header format: date,activity,engagement,goodness,isFlow):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _importController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'date,activity,engagement,goodness,isFlow\n2026-07-20T10:00:00.000,Design session,8.0,9.0,true',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _importController.text.trim();
              if (text.isEmpty) return;

              final provider = context.read<JournalProvider>();
              final count = await provider.importCsv(text);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(context); // Close bottom sheet
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      count > 0 ? 'Successfully imported $count entries!' : 'No valid entries found in CSV.',
                    ),
                    backgroundColor: count > 0 ? const Color(0xFF059669) : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Import Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CSV Data Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Export your journal entries or import entries in CSV format.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportCsvData(context);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export Data to CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _showImportDialog(context);
            },
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Import Data from CSV'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
