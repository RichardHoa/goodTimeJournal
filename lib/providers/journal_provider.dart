import 'package:flutter/material.dart';
import '../models/entry_model.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';

class JournalProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<JournalEntry> _entries = [];
  bool _isDarkMode = false;
  bool _isLoading = true;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  List<JournalEntry> get recentEntries => List.unmodifiable(_entries.take(5));
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  JournalProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _isDarkMode = await _storageService.loadDarkMode();
    _entries = await _storageService.loadEntries();

    // Sort entries newest first
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _storageService.saveDarkMode(_isDarkMode);
  }

  Future<void> addEntry({
    required String activity,
    required double engagement,
    required double goodness,
    bool isFlow = false,
    DateTime? timestamp,
  }) async {
    final newEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activity: activity,
      engagement: engagement,
      goodness: goodness,
      timestamp: timestamp ?? DateTime.now(),
      isFlow: isFlow,
    );

    _entries.insert(0, newEntry);
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    await _storageService.saveEntries(_entries);
  }

  Future<void> updateEntry(JournalEntry updatedEntry) async {
    final index = _entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      _entries[index] = updatedEntry;
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
      await _storageService.saveEntries(_entries);
    }
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _storageService.saveEntries(_entries);
  }

  String exportCsv() {
    return CsvService.exportToCsv(_entries);
  }

  Future<String?> exportAndSaveCsvToDownloads() async {
    final csvContent = exportCsv();
    final savedFile = await CsvService.saveCsvToDownloads(csvContent);
    return savedFile?.path;
  }

  Future<int> importCsv(String csvData) async {
    final imported = CsvService.importFromCsv(csvData);
    if (imported.isEmpty) return 0;

    _entries.addAll(imported);
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    await _storageService.saveEntries(_entries);
    return imported.length;
  }

  /// Groups entries by dateKey ("YYYY-MM-DD") sorted descending
  Map<String, List<JournalEntry>> get groupedEntries {
    final Map<String, List<JournalEntry>> grouped = {};
    for (final entry in _entries) {
      final key = entry.dateKey;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(entry);
    }
    return grouped;
  }

  // Dashboard Stats
  int get totalEntries => _entries.length;

  double get averageEngagement {
    if (_entries.isEmpty) return 0;
    final total = _entries.fold<double>(0, (sum, e) => sum + e.engagement);
    return total / _entries.length;
  }

  double get averageGoodness {
    if (_entries.isEmpty) return 0;
    final total = _entries.fold<double>(0, (sum, e) => sum + e.goodness);
    return total / _entries.length;
  }
}
