import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_model.dart';
import '../services/finance_csv.dart';
import '../services/finance_migration.dart';
import '../services/widget_service.dart';
import '../utils/amounts.dart';

class FinanceProvider with ChangeNotifier {
  static const String _balancesKey = FinanceMigration.balancesKey;
  static const String _transactionsKey = FinanceMigration.transactionsKey;
  static const String _fundsKey = FinanceMigration.fundsKey;
  static const String _trashKey = FinanceMigration.trashKey;
  static const String _categoriesKey = FinanceMigration.categoriesKey;

  /// Liquid accounts eligible for Money In and Money Out transactions
  static const List<String> liquidAccounts = ['Cash', 'VCB', 'MB', 'Techcombank'];
  /// Counts toward Total Money but is only ever edited directly
  static const String mbInvestment = 'MB investment';

  static const String balanceAdjustmentNote = 'Balance adjustment';

  /// How long deleted items stay in Trash before being removed for good.
  static const Duration trashRetention = Duration(days: 30);

  AccountBalances _balances = AccountBalances();
  List<FinanceTransaction> _transactions = [];
  List<Fund> _funds = [];
  final List<Category> _categories = [];
  List<TrashItem> _trash = [];
  bool _isLoading = true;
  /// Raw stored strings that couldn't be read, by key. They are copied
  /// aside before the first save overwrites them, so nothing is lost.
  final Map<String, String> _unreadable = {};

  AccountBalances get balances => _balances;
  /// Newest first by date; records on the same date and time, newest
  /// recorded first.
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);
  /// In creation order.
  List<Fund> get funds => List.unmodifiable(_funds);
  /// Every Category, Money In and Money Out, in creation order.
  List<Category> get categories => List.unmodifiable(_categories);
  /// Most recently deleted first.
  List<TrashItem> get trash => List.unmodifiable(_trash);
  double get fundsTotal => _funds.fold(0.0, (sum, f) => sum + f.amount);
  /// Total Money minus all Funds: what is free to spend.
  double get moneyLeft => _balances.totalMoney - fundsTotal;
  bool get isLoading => _isLoading;

  final DateTime Function() _now;

  /// Completes once stored data is loaded (and converted, if needed).
  late final Future<void> ready;

  FinanceProvider({DateTime Function()? now}) : _now = now ?? DateTime.now {
    ready = _loadData();
  }

  String _generateUniqueId() {
    final now = _now();
    final randomSuffix = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${now.microsecondsSinceEpoch}_$randomSuffix';
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    await FinanceMigration.run(prefs, now: _now);

    // Load balances
    final balancesJson = prefs.getString(_balancesKey);
    if (balancesJson != null && balancesJson.isNotEmpty) {
      try {
        _balances = AccountBalances.fromJson(jsonDecode(balancesJson));
      } catch (e) {
        _unreadable[_balancesKey] = balancesJson;
        debugPrint('Error loading finance balances: $e');
      }
    }

    // Load transactions
    final transactionsJson = prefs.getString(_transactionsKey);
    if (transactionsJson != null && transactionsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(transactionsJson);
        _transactions = jsonList.map((e) => FinanceTransaction.fromJson(e)).toList();
        _sortTransactions();
      } catch (e) {
        _transactions = [];
        _unreadable[_transactionsKey] = transactionsJson;
        debugPrint('Error loading finance transactions: $e');
      }
    }

    final fundsJson = prefs.getString(_fundsKey);
    if (fundsJson != null && fundsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(fundsJson);
        // Stored in creation order, which every change keeps.
        _funds = jsonList.map((e) => Fund.fromJson(e)).toList();
      } catch (e) {
        _funds = [];
        _unreadable[_fundsKey] = fundsJson;
        debugPrint('Error loading funds: $e');
      }
    }

    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson != null && categoriesJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(categoriesJson);
        // Stored in creation order, which every change keeps.
        _categories.addAll(jsonList.map((e) => Category.fromJson(e)));
      } catch (e) {
        _categories.clear();
        _unreadable[_categoriesKey] = categoriesJson;
        debugPrint('Error loading categories: $e');
      }
    }

    final trashJson = prefs.getString(_trashKey);
    if (trashJson != null && trashJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(trashJson);
        _trash = jsonList.map((e) => TrashItem.fromJson(e)).toList();
        _trash.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      } catch (e) {
        _trash = [];
        _unreadable[_trashKey] = trashJson;
        debugPrint('Error loading trash: $e');
      }
    }

    final expiredBefore = _now().subtract(trashRetention);
    final trashCount = _trash.length;
    _trash.removeWhere((item) => item.deletedAt.isBefore(expiredBefore));
    if (_trash.length != trashCount) await _saveData();

    _isLoading = false;
    notifyListeners();
    WidgetService.updateWidgetData(_balances.totalLiquid);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _unreadable.entries) {
      final asideKey = FinanceMigration.asideKey(entry.key, 'unreadable');
      if (!prefs.containsKey(asideKey)) await prefs.setString(asideKey, entry.value);
    }
    _unreadable.clear();
    await prefs.setString(_balancesKey, jsonEncode(_balances.toJson()));
    await prefs.setString(
      _transactionsKey,
      jsonEncode(_transactions.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(_fundsKey, jsonEncode(_funds.map((f) => f.toJson()).toList()));
    await prefs.setString(_categoriesKey, jsonEncode(_categories.map((c) => c.toJson()).toList()));
    await prefs.setString(_trashKey, jsonEncode(_trash.map((i) => i.toJson()).toList()));
    WidgetService.updateWidgetData(_balances.totalLiquid);
  }

  /// Set a balance directly. On a Liquid account this records a Balance
  /// adjustment (Money In/Out of the difference); on MB investment it
  /// records a Balance update.
  Future<void> updateAccountField(String fieldName, double newValue, {String? customNote}) async {
    final isLiquid = liquidAccounts.contains(fieldName);
    if (!isLiquid && fieldName != mbInvestment) return;

    newValue = roundAmount(newValue);
    final prevValue = _balances.of(fieldName);
    if (prevValue == newValue) return;

    _balances = _balances.adjusted(fieldName, newValue - prevValue);

    final TransactionType type;
    final String defaultNote;
    if (isLiquid) {
      type = newValue > prevValue ? TransactionType.moneyIn : TransactionType.moneyOut;
      defaultNote = balanceAdjustmentNote;
    } else {
      type = TransactionType.fieldUpdate;
      defaultNote = 'Directly updated balance from $prevValue k to $newValue k';
    }

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: type,
      account: fieldName,
      amount: roundAmount((newValue - prevValue).abs()),
      date: _now(),
      note: customNote ?? defaultNote,
      previousValue: prevValue,
      newValue: newValue,
    );

    _addTransaction(transaction);
    notifyListeners();
    await _saveData();
  }

  /// Record Money In transaction (Only liquid accounts: Cash, VCB, MB, Techcombank).
  /// A [categoryId] that isn't a Money In Category is ignored.
  Future<void> recordMoneyIn({
    required String account,
    required double amount,
    required DateTime date,
    required String note,
    String? categoryId,
  }) async {
    amount = roundAmount(amount);
    if (amount <= 0 || !liquidAccounts.contains(account)) return;

    final prevValue = _balances.of(account);
    _balances = _balances.adjusted(account, amount);
    final fullDate = _withCurrentTime(date);

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: TransactionType.moneyIn,
      account: account,
      amount: amount,
      date: fullDate,
      note: note.isEmpty ? 'Money in' : note,
      previousValue: prevValue,
      newValue: prevValue + amount,
      categoryId: _validCategoryId(categoryId, TransactionType.moneyIn),
    );

    _addTransaction(transaction);
    notifyListeners();
    await _saveData();
  }

  /// Record Money Out transaction (Only liquid accounts: Cash, VCB, MB, Techcombank).
  /// A [categoryId] that isn't a Money Out Category is ignored.
  Future<void> recordMoneyOut({
    required String account,
    required double amount,
    required DateTime date,
    required String note,
    String? categoryId,
  }) async {
    amount = roundAmount(amount);
    if (amount <= 0 || !liquidAccounts.contains(account)) return;

    final prevValue = _balances.of(account);
    _balances = _balances.adjusted(account, -amount);
    final fullDate = _withCurrentTime(date);

    final transaction = FinanceTransaction(
      id: _generateUniqueId(),
      type: TransactionType.moneyOut,
      account: account,
      amount: amount,
      date: fullDate,
      note: note.isEmpty ? 'Money out' : note,
      previousValue: prevValue,
      newValue: prevValue - amount,
      categoryId: _validCategoryId(categoryId, TransactionType.moneyOut),
    );

    _addTransaction(transaction);
    notifyListeners();
    await _saveData();
  }

  /// Move a transaction to Trash, reversing its effect on the balance.
  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final tx = _transactions.removeAt(index);
    _balances = _balances.adjusted(tx.account, -_balanceEffect(tx));
    _trash.insert(0, TrashItem.ofTransaction(id: _generateUniqueId(), deletedAt: _now(), transaction: tx));

    notifyListeners();
    await _saveData();
  }

  /// Update an existing transaction and recalculate account balance. Its
  /// Category becomes [newCategoryId] (null: Uncategorized); the type never
  /// changes.
  Future<void> updateTransaction({
    required String id,
    required String newAccount,
    required double newAmount,
    required DateTime newDate,
    required String newNote,
    String? newCategoryId,
  }) async {
    newAmount = roundAmount(newAmount);
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1 || newAmount <= 0) return;

    final oldTx = _transactions[index];
    final type = oldTx.type;

    AccountBalances updatedBalances = _balances;
    double? newPreviousVal = oldTx.previousValue;
    double? newNewVal = oldTx.newValue;

    // 1. Revert old transaction balance effect
    updatedBalances = updatedBalances.adjusted(oldTx.account, -_balanceEffect(oldTx));

    // 2. Apply new transaction balance effect
    if (type == TransactionType.moneyIn) {
      updatedBalances = updatedBalances.adjusted(newAccount, newAmount);
    } else if (type == TransactionType.moneyOut) {
      updatedBalances = updatedBalances.adjusted(newAccount, -newAmount);
    } else if (type == TransactionType.fieldUpdate) {
      final currentAccountBalance = updatedBalances.of(newAccount);
      bool isIncrease = true;
      if (oldTx.previousValue != null && oldTx.newValue != null) {
        isIncrease = oldTx.newValue! >= oldTx.previousValue!;
      }
      final delta = isIncrease ? newAmount : -newAmount;
      newPreviousVal = currentAccountBalance;
      newNewVal = currentAccountBalance + delta;
      updatedBalances = updatedBalances.adjusted(newAccount, delta);
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
      previousValue: newPreviousVal,
      newValue: newNewVal,
      categoryId: _validCategoryId(newCategoryId, type),
    );

    _transactions[index] = updatedTx;
    _sortTransactions();

    notifyListeners();
    await _saveData();
  }

  /// Read a CSV export. Every transaction and Fund gets a new id, so none
  /// can clash with an item in Trash, and Funds get the current time as
  /// their creation time, in the file's order. Throws a [FormatException]
  /// if the text isn't a finance export.
  FinanceImport readCsvExport(String csv) {
    return FinanceCsv.decode(csv, newId: _generateUniqueId, now: _now());
  }

  /// Replace balances, transactions, Funds and Categories with [data].
  /// Trash is kept.
  /// The replaced raw data is first set aside under 'before_import',
  /// replacing any earlier copy.
  Future<void> importData(FinanceImport data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_balancesKey, _transactionsKey, _fundsKey, _categoriesKey]) {
      final raw = prefs.getString(key);
      if (raw != null) await prefs.setString(FinanceMigration.asideKey(key, 'before_import'), raw);
    }

    _balances = data.balances;
    _transactions = [...data.transactions];
    _sortTransactions();
    _funds = [...data.funds];
    _categories
      ..clear()
      ..addAll(data.categories);

    notifyListeners();
    await _saveData();
  }

  /// Problem with a Fund name, or null if it can be used. [exceptId] is the
  /// Fund being renamed, which may keep its own name.
  String? validateFundName(String name, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return 'Please enter a name';
    final taken = _funds.any((f) => f.id != exceptId && f.name.trim().toLowerCase() == key);
    if (taken) return 'A Fund named "${name.trim()}" already exists';
    return null;
  }

  /// Add a Fund. Returns why it was rejected, or null on success.
  Future<String?> addFund({required String name, required double amount}) async {
    final error = validateFundName(name) ?? _validateFundAmount(amount);
    if (error != null) return error;

    _funds.add(Fund(id: _generateUniqueId(), name: name.trim(), amount: amount, createdAt: _now()));
    notifyListeners();
    await _saveData();
    return null;
  }

  /// Rename or change a Fund's amount. Returns why it was rejected, or null.
  Future<String?> updateFund(String id, {required String name, required double amount}) async {
    final index = _funds.indexWhere((f) => f.id == id);
    if (index == -1) return 'This Fund no longer exists';
    final error = validateFundName(name, exceptId: id) ?? _validateFundAmount(amount);
    if (error != null) return error;

    _funds[index] = _funds[index].copyWith(name: name.trim(), amount: amount);
    notifyListeners();
    await _saveData();
    return null;
  }

  /// Move a Fund to Trash.
  Future<void> deleteFund(String id) async {
    final index = _funds.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final fund = _funds.removeAt(index);
    _trash.insert(0, TrashItem.ofFund(id: _generateUniqueId(), deletedAt: _now(), fund: fund));
    notifyListeners();
    await _saveData();
  }

  String? _validateFundAmount(double amount) {
    if (amount.isNaN || amount < 0) return 'Please enter a valid positive number';
    return null;
  }

  /// Whole days until [item] is removed from Trash for good.
  int daysLeftInTrash(TrashItem item) {
    final left = item.deletedAt.add(trashRetention).difference(_now());
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  /// Put a trashed item back. A transaction's effect is re-applied to the
  /// current balance; a Fund comes back only if its name is still free.
  /// Returns why it couldn't be restored, or null on success.
  Future<String?> restoreFromTrash(String trashId) async {
    final index = _trash.indexWhere((i) => i.id == trashId);
    if (index == -1) return 'This item is no longer in Trash';
    final item = _trash[index];

    switch (item.kind) {
      case TrashKind.transaction:
        var tx = item.transaction!;
        // Its Category may have been deleted meanwhile.
        if (tx.categoryId != null && categoryById(tx.categoryId) == null) tx = tx.withCategory(null);
        _balances = _balances.adjusted(tx.account, _balanceEffect(tx));
        _addTransaction(tx);
      case TrashKind.fund:
        final fund = item.fund!;
        if (validateFundName(fund.name) != null) {
          return 'Can\'t restore "${fund.name}": a Fund with that name already exists. Rename it first.';
        }
        // Back into creation order, after any Fund created at the same time.
        final at = _funds.indexWhere((f) => f.createdAt.isAfter(fund.createdAt));
        _funds.insert(at == -1 ? _funds.length : at, fund);
      case TrashKind.category:
        final category = item.category!;
        if (validateCategoryName(category.name, category.type) != null) {
          return 'Can\'t restore "${category.name}": a Category with that name already exists. Rename it first.';
        }
        final at = _categories.indexWhere((c) => c.createdAt.isAfter(category.createdAt));
        _categories.insert(at == -1 ? _categories.length : at, category);
        // Back on the records that lost it, unless they've been given
        // another Category since.
        final lostIt = item.transactionIds.toSet();
        for (final (i, t) in _transactions.indexed) {
          if (lostIt.contains(t.id) && t.categoryId == null) _transactions[i] = t.withCategory(category.id);
        }
    }

    _trash.removeAt(index);
    notifyListeners();
    await _saveData();
    return null;
  }

  /// Every Category of [type] (Money In or Money Out), in creation order.
  List<Category> categoriesFor(TransactionType type) =>
      List.unmodifiable(_categories.where((c) => c.type == type));

  /// The live Category with [id], or null.
  Category? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// How many records use the Category with [id].
  int categoryUsage(String id) => _transactions.where((t) => t.categoryId == id).length;

  /// Problem with a Category name, or null if it can be used. Names are
  /// unique within [type], ignoring case. [exceptId] is the Category being
  /// renamed, which may keep its own name.
  String? validateCategoryName(String name, TransactionType type, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return 'Please enter a name';
    final taken = _categories.any((c) => c.type == type && c.id != exceptId && c.name.trim().toLowerCase() == key);
    if (taken) return 'A Category named "${name.trim()}" already exists';
    return null;
  }

  /// Add a Category for Money In or Money Out. Returns why it was rejected,
  /// or null on success.
  Future<String?> addCategory({required String name, required TransactionType type}) async {
    if (type == TransactionType.fieldUpdate) return 'Categories are for Money In and Money Out';
    final error = validateCategoryName(name, type);
    if (error != null) return error;

    _categories.add(Category(id: _generateUniqueId(), name: name.trim(), type: type, createdAt: _now()));
    notifyListeners();
    await _saveData();
    return null;
  }

  /// Rename a Category; every record using it shows the new name. Returns
  /// why it was rejected, or null.
  Future<String?> renameCategory(String id, String name) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return 'This Category no longer exists';
    final error = validateCategoryName(name, _categories[index].type, exceptId: id);
    if (error != null) return error;

    _categories[index] = _categories[index].copyWith(name: name.trim());
    notifyListeners();
    await _saveData();
    return null;
  }

  /// Move a Category to Trash; its records become Uncategorized.
  Future<void> deleteCategory(String id) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final category = _categories.removeAt(index);
    final lostIt = <String>[];
    for (final (i, t) in _transactions.indexed) {
      if (t.categoryId != id) continue;
      lostIt.add(t.id);
      _transactions[i] = t.withCategory(null);
    }
    _trash.insert(
      0,
      TrashItem.ofCategory(id: _generateUniqueId(), deletedAt: _now(), category: category, transactionIds: lostIt),
    );
    notifyListeners();
    await _saveData();
  }

  /// Set a Liquid account to [newBalance], recording [entries] as Money In
  /// (when it rises) or Money Out (when it falls). Whatever part of the
  /// change the entries don't explain becomes one Balance adjustment. When
  /// the entries add up to more than the change, they are recorded as
  /// typed, so the account ends past [newBalance].
  Future<void> explainBalanceChange({
    required String account,
    required double newBalance,
    required List<BalanceChangeEntry> entries,
  }) async {
    if (!liquidAccounts.contains(account)) return;
    final change = roundAmount(roundAmount(newBalance) - _balances.of(account));
    if (change == 0) return;

    final type = change > 0 ? TransactionType.moneyIn : TransactionType.moneyOut;
    final sign = change > 0 ? 1.0 : -1.0;
    var explained = 0.0;

    void record(double amount, DateTime date, String note, String? categoryId) {
      final prevValue = _balances.of(account);
      _balances = _balances.adjusted(account, sign * amount);
      _addTransaction(FinanceTransaction(
        id: _generateUniqueId(),
        type: type,
        account: account,
        amount: amount,
        date: date,
        note: note,
        previousValue: prevValue,
        newValue: _balances.of(account),
        categoryId: _validCategoryId(categoryId, type),
      ));
    }

    for (final entry in entries) {
      final amount = roundAmount(entry.amount);
      if (amount <= 0) continue;
      explained = roundAmount(explained + amount);
      final note = entry.note.trim();
      record(amount, _withCurrentTime(entry.date), note.isEmpty ? balanceAdjustmentNote : note, entry.categoryId);
    }

    final unexplained = roundAmount(change.abs() - explained);
    if (unexplained > 0) record(unexplained, _now(), balanceAdjustmentNote, null);

    notifyListeners();
    await _saveData();
  }

  /// [categoryId] if it is a live Category of [type], otherwise null.
  String? _validCategoryId(String? categoryId, TransactionType type) {
    final category = categoryById(categoryId);
    return category != null && category.type == type ? category.id : null;
  }

  /// [date]'s day at the current time of day, so records entered for the
  /// same day keep the order they were entered in.
  DateTime _withCurrentTime(DateTime date) {
    final now = _now();
    return DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second, now.millisecond);
  }

  /// Add [t] in its place: newest date first, and before others at the
  /// same date and time.
  void _addTransaction(FinanceTransaction t) {
    _transactions.insert(0, t);
    _sortTransactions();
  }

  /// Newest date first. Stable: records at the same date and time keep
  /// their current order, which is newest recorded first.
  void _sortTransactions() {
    final indexed = _transactions.indexed.toList()
      ..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    _transactions = [for (final (_, t) in indexed) t];
  }

  /// Remove one item from Trash for good.
  Future<void> deleteForever(String trashId) async {
    final count = _trash.length;
    _trash.removeWhere((i) => i.id == trashId);
    if (_trash.length == count) return;
    notifyListeners();
    await _saveData();
  }

  /// Remove everything from Trash for good.
  Future<void> emptyTrash() async {
    if (_trash.isEmpty) return;
    _trash.clear();
    notifyListeners();
    await _saveData();
  }

  /// How much [tx] changed its account's balance when it was recorded.
  double _balanceEffect(FinanceTransaction tx) {
    switch (tx.type) {
      case TransactionType.moneyIn:
        return tx.amount;
      case TransactionType.moneyOut:
        return -tx.amount;
      case TransactionType.fieldUpdate:
        if (tx.previousValue == null || tx.newValue == null) return 0.0;
        return tx.newValue! - tx.previousValue!;
    }
  }
}
