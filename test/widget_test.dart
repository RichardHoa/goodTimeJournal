import 'package:flutter_test/flutter_test.dart';
import 'package:good_time_journal_app/models/entry_model.dart';
import 'package:good_time_journal_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalEntry model & StorageService tests', () {
    test('JournalEntry serialization to and from JSON', () {
      final now = DateTime(2026, 7, 19, 14, 30);
      final entry = JournalEntry(
        id: 'test-1',
        activity: 'Coding Flutter App',
        engagement: 8.5,
        goodness: 9.0,
        timestamp: now,
      );

      expect(entry.dateKey, '2026-07-19');

      final json = entry.toJson();
      final restored = JournalEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.activity, entry.activity);
      expect(restored.engagement, entry.engagement);
      expect(restored.goodness, entry.goodness);
      expect(restored.timestamp, entry.timestamp);
    });

    test('StorageService saves and loads entries', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      final entries = [
        JournalEntry(
          id: '1',
          activity: 'Reading',
          engagement: 7.0,
          goodness: 8.0,
          timestamp: DateTime.now(),
        ),
      ];

      await storage.saveEntries(entries);
      final loaded = await storage.loadEntries();

      expect(loaded.length, 1);
      expect(loaded.first.activity, 'Reading');
    });
  });
}
