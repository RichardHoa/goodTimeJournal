import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Moves CSV text between the app and the device: saving, sharing and
/// picking files. The finance format itself lives in `FinanceCsv`.
class CsvService {
  /// Builds a timestamped CSV file name, e.g. `mixapp_finance_20261003_142501.csv`.
  static String csvFileName({String filenamePrefix = 'mixapp', DateTime? now}) {
    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${filenamePrefix}_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}.csv';
  }

  /// Opens the system "save as" picker so the user chooses the folder.
  /// Returns the saved location, or null if the user cancelled.
  static Future<Uri?> saveCsvToUserFolder(String csvContent, {String filenamePrefix = 'mixapp'}) {
    return FilePicker.saveFile(
      dialogTitle: 'Save CSV',
      fileName: csvFileName(filenamePrefix: filenamePrefix),
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );
  }

  /// Writes the CSV to a temp file and opens the native share sheet.
  static Future<ShareResult> shareCsv(
    String csvContent, {
    String filenamePrefix = 'mixapp',
    Rect? sharePositionOrigin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${csvFileName(filenamePrefix: filenamePrefix)}');
    await file.writeAsString(csvContent);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'mixApp finance export',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Opens the system file picker and reads the chosen file as UTF-8.
  /// Returns null if the user cancelled.
  static Future<({String name, String text})?> pickCsv() async {
    // Any type: CSV MIME filters grey out valid files on some Android devices.
    final file = await FilePicker.pickFile(dialogTitle: 'Import CSV');
    if (file == null) return null;
    return (name: file.name, text: utf8.decode(await file.readAsBytes(), allowMalformed: true));
  }
}
