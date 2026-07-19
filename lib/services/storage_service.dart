import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry_model.dart';

class StorageService {
  static const String _entriesKey = 'gtj_journal_entries';
  static const String _themeModeKey = 'gtj_is_dark_mode';

  // Save entries to SharedPreferences
  Future<void> saveEntries(List<JournalEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      entries.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_entriesKey, jsonString);
  }

  // Load entries from SharedPreferences
  Future<List<JournalEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_entriesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save Dark Mode state
  Future<void> saveDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDarkMode);
  }

  // Load Dark Mode state
  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeModeKey) ?? false; // Default to light mode
  }
}
