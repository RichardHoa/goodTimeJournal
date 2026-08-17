import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/csv_service.dart';
import '../services/finance_csv.dart';
import 'finance_transaction_tile.dart';

enum _ExportTarget { folder, share }

const String _filenamePrefix = 'mixapp_finance';

/// Asks where to send the finance CSV, then saves or shares it.
Future<void> exportFinanceCsv(BuildContext context) async {
  final target = await showModalBottomSheet<_ExportTarget>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Save to folder'),
            subtitle: const Text('Choose where to save the CSV file'),
            onTap: () => Navigator.of(ctx).pop(_ExportTarget.folder),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share'),
            subtitle: const Text('Send the CSV to another app'),
            onTap: () => Navigator.of(ctx).pop(_ExportTarget.share),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return;

  final provider = context.read<FinanceProvider>();
  final csv = FinanceCsv.encode(provider.balances, provider.transactions, provider.funds);
  try {
    switch (target) {
      case _ExportTarget.folder:
        final uri = await CsvService.saveCsvToUserFolder(csv, filenamePrefix: _filenamePrefix);
        if (uri != null && context.mounted) _showMessage(context, 'CSV saved successfully.');
      case _ExportTarget.share:
        // iPad needs an anchor rect for the share popover.
        final box = context.findRenderObject() as RenderBox?;
        await CsvService.shareCsv(
          csv,
          filenamePrefix: _filenamePrefix,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
    }
  } catch (e) {
    debugPrint('CSV export failed: $e');
    if (context.mounted) _showMessage(context, 'Failed to export CSV file.', isError: true);
  }
}

/// Picks a finance CSV, shows what it holds, and replaces the data once the
/// user confirms.
Future<void> importFinanceCsv(BuildContext context) async {
  final provider = context.read<FinanceProvider>();

  final String fileName;
  final FinanceImport data;
  try {
    final file = await CsvService.pickCsv();
    if (file == null) return;
    fileName = file.name;
    data = provider.readCsvExport(file.text);
  } on FormatException catch (e) {
    if (context.mounted) {
      _showMessage(context, 'This file isn\'t a mixApp finance export (${e.message}).', isError: true);
    }
    return;
  } catch (e) {
    debugPrint('CSV import failed to read the file: $e');
    if (context.mounted) _showMessage(context, 'Failed to read the file.', isError: true);
    return;
  }
  if (!context.mounted) return;

  String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
  final imported = '${count(data.transactions.length, 'transaction')} and ${count(data.funds.length, 'Fund')}';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Replace your data?'),
      content: Text(
        '$fileName has $imported, with Total Money of '
        '${FinanceTransactionTile.formatVnd(data.balances.totalMoney)}.\n\n'
        'Your current ${count(provider.transactions.length, 'transaction')}, '
        '${count(provider.funds.length, 'Fund')} and balances will be replaced. Trash is kept.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Replace')),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await provider.importData(data);
  } catch (e) {
    debugPrint('CSV import failed to save: $e');
    if (context.mounted) _showMessage(context, 'Failed to import the file.', isError: true);
    return;
  }
  if (context.mounted) _showMessage(context, 'Imported $imported.');
}

void _showMessage(BuildContext context, String message, {bool isError = false}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: isError ? colors.error : colors.primary),
  );
}
