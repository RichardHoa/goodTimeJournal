import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/entry_model.dart';
import '../models/finance_model.dart';

class CsvService {
  /// Exports list of GTJ entries to CSV string
  static String exportToCsv(List<JournalEntry> entries) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('date,activity,engagement,goodness,isFlow');

    for (final entry in entries) {
      final String dateStr = entry.timestamp.toIso8601String();
      final String escapedActivity = _escapeCsvField(entry.activity);
      buffer.writeln('$dateStr,$escapedActivity,${entry.engagement},${entry.goodness},${entry.isFlow}');
    }

    return buffer.toString();
  }

  /// Exports finance balances and transactions to CSV
  static String exportFinanceToCsv(AccountBalances balances, List<FinanceTransaction> transactions) {
    final StringBuffer buffer = StringBuffer();

    // Summary Section
    buffer.writeln('--- ACCOUNT BALANCES SUMMARY ---');
    buffer.writeln('Account,Amount (k VND),Amount (VND)');
    buffer.writeln('Cash,${balances.cash},${(balances.cash * 1000).toInt()}');
    buffer.writeln('VCB,${balances.vcb},${(balances.vcb * 1000).toInt()}');
    buffer.writeln('MB,${balances.mb},${(balances.mb * 1000).toInt()}');
    buffer.writeln('Techcombank,${balances.techcombank},${(balances.techcombank * 1000).toInt()}');
    buffer.writeln('MB fund,${balances.mbFund},${(balances.mbFund * 1000).toInt()}');
    buffer.writeln('Total Money,${balances.totalMoney},${(balances.totalMoney * 1000).toInt()}');
    buffer.writeln('Backup Fund,${balances.backupFund},${(balances.backupFund * 1000).toInt()}');
    buffer.writeln('Money Left,${balances.moneyLeft},${(balances.moneyLeft * 1000).toInt()}');
    buffer.writeln();

    // Transactions Section
    buffer.writeln('--- TRANSACTIONS LOG ---');
    buffer.writeln('date,type,account,amount_k_vnd,amount_vnd,note,previous_value_k_vnd,new_value_k_vnd');
    for (final t in transactions) {
      final dateStr = t.formattedDate;
      final typeStr = t.type.name;
      final accountStr = _escapeCsvField(t.account);
      final noteStr = _escapeCsvField(t.note);
      final amountK = t.amount;
      final amountVnd = (t.amount * 1000).toInt();
      final prevStr = t.previousValue != null ? t.previousValue.toString() : '';
      final newStr = t.newValue != null ? t.newValue.toString() : '';

      buffer.writeln('$dateStr,$typeStr,$accountStr,$amountK,$amountVnd,$noteStr,$prevStr,$newStr');
    }

    return buffer.toString();
  }

  /// Saves CSV string to the device's Download folder safely
  static Future<File?> saveCsvToDownloads(String csvContent, {String filenamePrefix = 'mixapp'}) async {
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = await getExternalStorageDirectory();
      } else {
        targetDir = await getDownloadsDirectory();
      }
      targetDir ??= await getApplicationDocumentsDirectory();

      final now = DateTime.now();
      final timestampStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final filePath = '${targetDir.path}/${filenamePrefix}_$timestampStr.csv';
      final file = File(filePath);
      return await file.writeAsString(csvContent);
    } catch (e) {
      return null;
    }
  }

  /// Imports CSV string into list of JournalEntry objects
  static List<JournalEntry> importFromCsv(String csvContent) {
    final List<JournalEntry> imported = [];
    final List<String> lines = _splitCsvLines(csvContent);

    if (lines.isEmpty) return imported;

    int startIdx = 0;
    final firstLineLower = lines[0].toLowerCase();
    if (firstLineLower.contains('date') && firstLineLower.contains('activity')) {
      startIdx = 1;
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.length < 4) continue;

      try {
        final DateTime timestamp = DateTime.tryParse(fields[0].trim()) ?? DateTime.now();
        final String activity = fields[1].trim();
        final double engagement = double.tryParse(fields[2].trim()) ?? 5.0;
        final double goodness = double.tryParse(fields[3].trim()) ?? 5.0;
        final bool isFlow = fields.length > 4 ? (fields[4].trim().toLowerCase() == 'true' || fields[4].trim() == '1') : false;

        imported.add(
          JournalEntry(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
            activity: activity,
            engagement: engagement,
            goodness: goodness,
            timestamp: timestamp,
            isFlow: isFlow,
          ),
        );
      } catch (_) {
        // Skip malformed row safely
      }
    }

    return imported;
  }

  static String _escapeCsvField(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  static List<String> _splitCsvLines(String content) {
    final List<String> lines = [];
    final StringBuffer sb = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
        sb.write(char);
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        lines.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    if (sb.isNotEmpty) {
      lines.add(sb.toString());
    }
    return lines;
  }

  static List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    final StringBuffer sb = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        fields.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    fields.add(sb.toString());
    return fields;
  }
}
