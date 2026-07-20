import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/entry_model.dart';

class CsvService {
  /// Exports list of entries to CSV string with header:
  /// date,activity,engagement,goodness,isFlow
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

  /// Saves CSV string to the device's Download folder
  static Future<File?> saveCsvToDownloads(String csvContent) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          downloadsDir = dir;
        } else {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      downloadsDir ??= await getApplicationDocumentsDirectory();

      final now = DateTime.now();
      final timestampStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final filePath = '${downloadsDir.path}/good_time_journal_$timestampStr.csv';
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

    // Check if first line is header
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
          i++; // skip \n in \r\n
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
          i++; // Skip escaped quote
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
