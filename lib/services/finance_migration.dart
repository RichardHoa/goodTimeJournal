import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raw stored finance data, decoded but not yet turned into models.
/// A null field means nothing was stored under that key.
class FinanceRawData {
  Map<String, dynamic>? balances;
  List<Map<String, dynamic>>? transactions;
  List<Map<String, dynamic>>? funds;

  FinanceRawData({this.balances, this.transactions, this.funds});
}

/// Converts stored finance data to the current format, once.
///
/// Data with no stored version is v1. Every step runs on the decoded JSON in
/// memory first; only when all of them succeed are the original raw strings
/// copied to backup keys, the converted data written, and the version set.
/// Any failure leaves storage untouched and the version unchanged.
class FinanceMigration {
  static const String balancesKey = 'mixapp_finance_balances';
  static const String transactionsKey = 'mixapp_finance_transactions';
  static const String fundsKey = 'mixapp_finance_funds';
  static const String trashKey = 'mixapp_finance_trash';
  static const String dataVersionKey = 'mixapp_finance_data_version';
  /// Where raw stored data under [key] is set aside for recovery by hand,
  /// before [reason] replaces it. Nothing reads these keys back.
  static String asideKey(String key, String reason) => '${key}_$reason';
  /// Where the raw strings are copied before converting from [version].
  static String balancesBackupKey(int version) => asideKey(balancesKey, 'backup_v$version');
  static String transactionsBackupKey(int version) => asideKey(transactionsKey, 'backup_v$version');

  static const List<String> _liquidAccounts = ['Cash', 'VCB', 'MB', 'Techcombank'];

  /// Steps keyed by the version they convert the data to, in order.
  static final Map<int, void Function(FinanceRawData, DateTime now)> _steps = {
    2: (data, _) => _toV2(data),
    3: _toV3,
  };

  static int get currentVersion => _steps.keys.last;

  static Future<void> run(SharedPreferences prefs, {DateTime Function() now = DateTime.now}) async {
    final storedVersion = prefs.getInt(dataVersionKey) ?? 1;
    if (storedVersion >= currentVersion) return;

    final rawBalances = prefs.getString(balancesKey);
    final rawTransactions = prefs.getString(transactionsKey);
    final rawFunds = prefs.getString(fundsKey);

    final FinanceRawData data;
    try {
      data = FinanceRawData(
        balances: _decodeBalances(rawBalances),
        transactions: _decodeRecords(rawTransactions),
        funds: _decodeRecords(rawFunds),
      );
      for (final step in _steps.entries) {
        if (step.key > storedVersion) step.value(data, now());
      }
    } catch (e) {
      debugPrint('Finance data conversion from v$storedVersion failed, data left as is: $e');
      return;
    }

    try {
      // Never overwrite an earlier backup: a half-finished previous run may
      // already have rewritten the main keys.
      final balancesBackup = balancesBackupKey(storedVersion);
      final transactionsBackup = transactionsBackupKey(storedVersion);
      if (rawBalances != null && !prefs.containsKey(balancesBackup)) {
        await prefs.setString(balancesBackup, rawBalances);
      }
      if (rawTransactions != null && !prefs.containsKey(transactionsBackup)) {
        await prefs.setString(transactionsBackup, rawTransactions);
      }
      if (data.balances != null) {
        await prefs.setString(balancesKey, jsonEncode(data.balances));
      }
      if (data.transactions != null) {
        await prefs.setString(transactionsKey, jsonEncode(data.transactions));
      }
      if (data.funds != null) {
        await prefs.setString(fundsKey, jsonEncode(data.funds));
      }
      await prefs.setInt(dataVersionKey, currentVersion);
    } catch (e) {
      debugPrint('Finance data conversion could not be saved: $e');
    }
  }

  static Map<String, dynamic>? _decodeBalances(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static List<Map<String, dynamic>>? _decodeRecords(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// v2: "MB fund" becomes "MB investment", and direct edits to Liquid
  /// accounts become Money In / Money Out of the difference.
  static void _toV2(FinanceRawData data) {
    final balances = data.balances;
    if (balances != null && balances.containsKey('mbFund')) {
      final mbFund = balances.remove('mbFund');
      balances.putIfAbsent('mbInvestment', () => mbFund);
    }

    for (final t in data.transactions ?? const <Map<String, dynamic>>[]) {
      if (t['account'] == 'MB fund') t['account'] = 'MB investment';

      if (t['type'] != 'fieldUpdate' || !_liquidAccounts.contains(t['account'])) continue;
      final previous = t['previousValue'];
      final next = t['newValue'];
      // Without both values the direction is unknown: keep the stored record.
      if (previous is! num || next is! num || previous == next) continue;

      t['type'] = next > previous ? 'moneyIn' : 'moneyOut';
      t['amount'] = (next - previous).abs().toDouble();
    }
  }

  /// v3: the single Backup Fund becomes a Fund named "Backup" (when it holds
  /// anything), and its old history records are dropped. No balance changes.
  static void _toV3(FinanceRawData data, DateTime now) {
    final backupFund = data.balances?.remove('backupFund');
    if (backupFund is num && backupFund > 0) {
      (data.funds ??= []).add({
        'id': 'backup_${now.microsecondsSinceEpoch}',
        'name': 'Backup',
        'amount': backupFund.toDouble(),
        'createdAt': now.toIso8601String(),
      });
    }

    data.transactions?.removeWhere((t) => t['type'] == 'fieldUpdate' && t['account'] == 'Backup Fund');
  }
}
