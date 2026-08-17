import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_model.dart';
import '../services/widget_service.dart';

class FinanceProvider with ChangeNotifier {
  static const String _balancesKey = 'mixapp_finance_balances';
  static const String _transactionsKey = 'mixapp_finance_transactions';

  /// Liquid accounts eligible for Money In and Money Out transactions
  static const List<String> liquidAccounts = ['Cash', 'VCB', 'MB', 'Techcombank'];
  /// Reserve funds edited directly in Accounts & Balances
  static const List<String> reserveFunds = ['MB fund', 'Backup Fund'];

  AccountBalances _balances = AccountBalances();
  List<FinanceTransaction> _transactions = [];
  bool _isLoading = true;

  AccountBalances get balances => _balances;
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  FinanceProvider() {
    _loadData();
  }

  String _generateUniqueId() {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${now.microsecondsSinceEpoch}_$randomSuffix';
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load balances
    final balancesJson = prefs.getString(_balancesKey);
    if (balancesJson != null && balancesJson.isNotEmpty) {
      try {
        _balances = AccountBalances.fromJson(jsonDecode(balancesJson));
      } catch (e) {
        debugPrint('Error loading finance balances: $e');
      }
    }

    // Load transactions
    final transactionsJson = prefs.getString(_transactionsKey);
    if (transactionsJson != null && transactionsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(transactionsJson);
        _transactions = jsonList.map((e) => FinanceTransaction.fromJson(e)).toList();
        // Sort newest transactions first
        _transactions.sort((a, b) => b.date.compareTo(a.date));
      } catch (e) {
        debugPrint('Error loading finance transactions: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    WidgetService.updateWidgetData(_balances.totalLiquid);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_balancesKey, jsonEncode(_balances.toJson()));
    await prefs.setString(
      _transactionsKey,
      jsonEncode(_transactions.map((t) => t.toJson()).toList()),
    );
    WidgetService.updateWidgetData(_balances.totalLiquid);
  }

  /// Update a specific field directly (Cash, VCB, MB, Techcombank, MB fund, Backup Fund)
  Future<void> updateAccountField(String fieldName, double newValue, {String? customNote}) async {
    double prevValue = 0.0;
    AccountBalances newBalances = _balances;

    switch (fieldName) {
      case 'Cash':
        prevValue = _balances.cash;
        newBalances = _balances.copyWith(cash: newValue);
        break;
      case 'VCB':
        prevValue = _balances.vcb;
        newBalances = _balances.copyWith(vcb: newValue);
        break;
      case 'MB':
        prevValue = _balances.mb;
        newBalances = _balances.copyWith(mb: newValue);
        break;
      case 'Techcombank':
        prevValue = _balances.techcombank;
        newBalances = _balances.copyWith(techcombank: newValue);
        break;
      case 'MB fund':
        prevValue = _balances.mbFund;
        newBalances = _balances.copyWith(mbFund: newValue);
        break;
      case 'Backup Fund':
        prevValue = _balances.backupFund;
        newBalances = _balances.copyWith(backupFund: newValue);
        break;
      default:
        return;
    }

    if (prevValue == newValue) return;

    _balances = newBalances;
    final now = DateTime.now();

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: TransactionType.fieldUpdate,
      account: fieldName,
      amount: (newValue - prevValue).abs(),
      date: now,
      note: customNote ?? 'Directly updated balance from $prevValue k to $newValue k',
      previousValue: prevValue,
      newValue: newValue,
    );

    _transactions.insert(0, transaction);
    notifyListeners();
    await _saveData();
  }

  /// Record Money In transaction (Only liquid accounts: Cash, VCB, MB, Techcombank)
  Future<void> recordMoneyIn({
    required String account,
    required double amount,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0 || !liquidAccounts.contains(account)) return;

    double prevValue = 0.0;
    AccountBalances newBalances = _balances;

    switch (account) {
      case 'Cash':
        prevValue = _balances.cash;
        newBalances = _balances.copyWith(cash: _balances.cash + amount);
        break;
      case 'VCB':
        prevValue = _balances.vcb;
        newBalances = _balances.copyWith(vcb: _balances.vcb + amount);
        break;
      case 'MB':
        prevValue = _balances.mb;
        newBalances = _balances.copyWith(mb: _balances.mb + amount);
        break;
      case 'Techcombank':
        prevValue = _balances.techcombank;
        newBalances = _balances.copyWith(techcombank: _balances.techcombank + amount);
        break;
      default:
        return;
    }

    _balances = newBalances;
    final now = DateTime.now();
    final fullDate = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: TransactionType.moneyIn,
      account: account,
      amount: amount,
      date: fullDate,
      note: note.isEmpty ? 'Money in' : note,
      previousValue: prevValue,
      newValue: prevValue + amount,
    );

    _transactions.insert(0, transaction);
    notifyListeners();
    await _saveData();
  }

  /// Record Money Out transaction (Only liquid accounts: Cash, VCB, MB, Techcombank)
  Future<void> recordMoneyOut({
    required String account,
    required double amount,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0 || !liquidAccounts.contains(account)) return;

    double prevValue = 0.0;
    AccountBalances newBalances = _balances;

    switch (account) {
      case 'Cash':
        prevValue = _balances.cash;
        newBalances = _balances.copyWith(cash: _balances.cash - amount);
        break;
      case 'VCB':
        prevValue = _balances.vcb;
        newBalances = _balances.copyWith(vcb: _balances.vcb - amount);
        break;
      case 'MB':
        prevValue = _balances.mb;
        newBalances = _balances.copyWith(mb: _balances.mb - amount);
        break;
      case 'Techcombank':
        prevValue = _balances.techcombank;
        newBalances = _balances.copyWith(techcombank: _balances.techcombank - amount);
        break;
      default:
        return;
    }

    _balances = newBalances;
    final now = DateTime.now();
    final fullDate = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: TransactionType.moneyOut,
      account: account,
      amount: amount,
      date: fullDate,
      note: note.isEmpty ? 'Money out' : note,
      previousValue: prevValue,
      newValue: prevValue - amount,
    );

    _transactions.insert(0, transaction);
    notifyListeners();
    await _saveData();
  }

  /// Delete transaction from log
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveData();
  }

  /// Update an existing transaction and recalculate account balance
  Future<void> updateTransaction({
    required String id,
    required String newAccount,
    required double newAmount,
    required DateTime newDate,
    required String newNote,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1 || newAmount <= 0) return;

    final oldTx = _transactions[index];
    final type = oldTx.type;

    AccountBalances updatedBalances = _balances;

    // 1. Revert old transaction balance effect
    if (type == TransactionType.moneyIn) {
      updatedBalances = _adjustAccountBalance(updatedBalances, oldTx.account, -oldTx.amount);
    } else if (type == TransactionType.moneyOut) {
      updatedBalances = _adjustAccountBalance(updatedBalances, oldTx.account, oldTx.amount);
    }

    // 2. Apply new transaction balance effect
    if (type == TransactionType.moneyIn) {
      updatedBalances = _adjustAccountBalance(updatedBalances, newAccount, newAmount);
    } else if (type == TransactionType.moneyOut) {
      updatedBalances = _adjustAccountBalance(updatedBalances, newAccount, -newAmount);
    }

    _balances = updatedBalances;

    // 3. Replace transaction item
    final updatedTx = FinanceTransaction(
      id: oldTx.id,
      type: type,
      account: newAccount,
      amount: newAmount,
      date: newDate,
      note: newNote,
      previousValue: oldTx.previousValue,
      newValue: oldTx.newValue,
    );

    _transactions[index] = updatedTx;
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
    await _saveData();
  }

  AccountBalances _adjustAccountBalance(AccountBalances b, String account, double delta) {
    switch (account) {
      case 'Cash':
        return b.copyWith(cash: b.cash + delta);
      case 'VCB':
        return b.copyWith(vcb: b.vcb + delta);
      case 'MB':
        return b.copyWith(mb: b.mb + delta);
      case 'Techcombank':
        return b.copyWith(techcombank: b.techcombank + delta);
      case 'MB fund':
        return b.copyWith(mbFund: b.mbFund + delta);
      case 'Backup Fund':
        return b.copyWith(backupFund: b.backupFund + delta);
      default:
        return b;
    }
  }
}
