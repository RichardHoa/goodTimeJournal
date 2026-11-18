import 'package:intl/intl.dart';

enum TransactionType {
  moneyIn,
  moneyOut,
  fieldUpdate,
}

class AccountBalances {
  final double cash;
  final double vcb;
  final double mb;
  final double techcombank;
  final double mbInvestment;

  AccountBalances({
    this.cash = 0.0,
    this.vcb = 0.0,
    this.mb = 0.0,
    this.techcombank = 0.0,
    this.mbInvestment = 0.0,
  });

  /// A balance per account, by account name; a missing account is 0.
  factory AccountBalances.fromAccounts(Map<String, double> balances) {
    return AccountBalances(
      cash: balances['Cash'] ?? 0.0,
      vcb: balances['VCB'] ?? 0.0,
      mb: balances['MB'] ?? 0.0,
      techcombank: balances['Techcombank'] ?? 0.0,
      mbInvestment: balances['MB investment'] ?? 0.0,
    );
  }

  /// Every account's name, in display order.
  static final List<String> accounts = AccountBalances().toAccounts().keys.toList();

  double get totalMoney => cash + vcb + mb + techcombank + mbInvestment;
  double get totalLiquid => cash + vcb + mb + techcombank;

  /// Each account's balance by name, in display order.
  Map<String, double> toAccounts() {
    return {
      'Cash': cash,
      'VCB': vcb,
      'MB': mb,
      'Techcombank': techcombank,
      'MB investment': mbInvestment,
    };
  }

  /// The balance of [account], or 0 for an unknown account.
  double of(String account) => toAccounts()[account] ?? 0.0;

  /// A copy with [delta] added to [account]; an unknown account changes nothing.
  AccountBalances adjusted(String account, double delta) {
    final balances = toAccounts();
    final current = balances[account];
    if (current == null) return this;
    balances[account] = current + delta;
    return AccountBalances.fromAccounts(balances);
  }

  AccountBalances copyWith({
    double? cash,
    double? vcb,
    double? mb,
    double? techcombank,
    double? mbInvestment,
  }) {
    return AccountBalances(
      cash: cash ?? this.cash,
      vcb: vcb ?? this.vcb,
      mb: mb ?? this.mb,
      techcombank: techcombank ?? this.techcombank,
      mbInvestment: mbInvestment ?? this.mbInvestment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cash': cash,
      'vcb': vcb,
      'mb': mb,
      'techcombank': techcombank,
      'mbInvestment': mbInvestment,
    };
  }

  factory AccountBalances.fromJson(Map<String, dynamic> json) {
    return AccountBalances(
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      vcb: (json['vcb'] as num?)?.toDouble() ?? 0.0,
      mb: (json['mb'] as num?)?.toDouble() ?? 0.0,
      techcombank: (json['techcombank'] as num?)?.toDouble() ?? 0.0,
      // Falls back to the v1 'mbFund' field if the conversion hasn't run yet.
      mbInvestment: ((json['mbInvestment'] ?? json['mbFund']) as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FinanceTransaction {
  final String id;
  final TransactionType type;
  final String account;
  final double amount;
  final DateTime date;
  final String note;
  final double? previousValue;
  final double? newValue;
  /// The [Category] this Money In or Money Out was for; null when
  /// Uncategorized.
  final String? categoryId;

  FinanceTransaction({
    required this.id,
    required this.type,
    required this.account,
    required this.amount,
    required this.date,
    required this.note,
    this.previousValue,
    this.newValue,
    this.categoryId,
  });

  /// A copy with its Category set to [categoryId] (null: Uncategorized).
  FinanceTransaction withCategory(String? categoryId) {
    return FinanceTransaction(
      id: id,
      type: type,
      account: account,
      amount: amount,
      date: date,
      note: note,
      previousValue: previousValue,
      newValue: newValue,
      categoryId: categoryId,
    );
  }

  /// A direct edit to MB investment, as opposed to a Money In/Out.
  bool get isBalanceUpdate => type == TransactionType.fieldUpdate && account == 'MB investment';

  String get formattedDate {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'account': account,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'previousValue': previousValue,
      'newValue': newValue,
      'categoryId': categoryId,
    };
  }

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] != null) {
      final dateStr = json['date'].toString();
      parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    TransactionType typeEnum;
    try {
      typeEnum = TransactionType.values.byName(json['type'] ?? 'moneyIn');
    } catch (_) {
      typeEnum = TransactionType.moneyIn;
    }

    return FinanceTransaction(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: typeEnum,
      account: json['account'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      note: json['note'] as String? ?? '',
      previousValue: (json['previousValue'] as num?)?.toDouble(),
      newValue: (json['newValue'] as num?)?.toDouble(),
      categoryId: json['categoryId'] as String?,
    );
  }
}

/// A named amount set aside for a purpose: a claim on Total Money, not money
/// held anywhere.
class Fund {
  final String id;
  final String name;
  final double amount;
  final DateTime createdAt;

  Fund({
    required this.id,
    required this.name,
    required this.amount,
    required this.createdAt,
  });

  Fund copyWith({String? name, double? amount}) {
    return Fund(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Fund.fromJson(Map<String, dynamic> json) {
    return Fund(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// One Money In or Money Out the user types in to explain part of a
/// balance change.
class BalanceChangeEntry {
  final double amount;
  final String note;
  final DateTime date;
  final String? categoryId;

  const BalanceChangeEntry({
    required this.amount,
    required this.note,
    required this.date,
    this.categoryId,
  });
}

/// A user-defined label saying what a Money In or Money Out was for. Money
/// In and Money Out each have their own Categories, told apart by [type].
class Category {
  final String id;
  final String name;
  /// [TransactionType.moneyIn] or [TransactionType.moneyOut].
  final TransactionType type;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  Category copyWith({String? name}) {
    return Category(id: id, name: name ?? this.name, type: type, createdAt: createdAt);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

enum TrashKind { transaction, fund, category }

/// A deleted transaction, Fund or Category, kept in Trash for 30 days.
class TrashItem {
  final String id;
  final TrashKind kind;
  final DateTime deletedAt;
  final FinanceTransaction? transaction;
  final Fund? fund;
  final Category? category;
  /// For a Category: the records it was removed from, which get it back on
  /// restore.
  final List<String> transactionIds;

  TrashItem.ofTransaction({required this.id, required this.deletedAt, required FinanceTransaction this.transaction})
      : kind = TrashKind.transaction,
        fund = null,
        category = null,
        transactionIds = const [];

  TrashItem.ofFund({required this.id, required this.deletedAt, required Fund this.fund})
      : kind = TrashKind.fund,
        transaction = null,
        category = null,
        transactionIds = const [];

  TrashItem.ofCategory({
    required this.id,
    required this.deletedAt,
    required Category this.category,
    required this.transactionIds,
  })  : kind = TrashKind.category,
        transaction = null,
        fund = null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'deletedAt': deletedAt.toIso8601String(),
      'payload': switch (kind) {
        TrashKind.transaction => transaction!.toJson(),
        TrashKind.fund => fund!.toJson(),
        TrashKind.category => category!.toJson(),
      },
      if (kind == TrashKind.category) 'transactionIds': transactionIds,
    };
  }

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final deletedAt = DateTime.parse(json['deletedAt'] as String);
    final payload = Map<String, dynamic>.from(json['payload'] as Map);
    switch (TrashKind.values.byName(json['kind'] as String)) {
      case TrashKind.transaction:
        return TrashItem.ofTransaction(id: id, deletedAt: deletedAt, transaction: FinanceTransaction.fromJson(payload));
      case TrashKind.fund:
        return TrashItem.ofFund(id: id, deletedAt: deletedAt, fund: Fund.fromJson(payload));
      case TrashKind.category:
        return TrashItem.ofCategory(
          id: id,
          deletedAt: deletedAt,
          category: Category.fromJson(payload),
          transactionIds: List<String>.from(json['transactionIds'] as List? ?? const []),
        );
    }
  }
}
