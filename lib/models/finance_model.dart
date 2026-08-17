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
  final double mbFund;
  final double backupFund;

  AccountBalances({
    this.cash = 0.0,
    this.vcb = 0.0,
    this.mb = 0.0,
    this.techcombank = 0.0,
    this.mbFund = 0.0,
    this.backupFund = 0.0,
  });

  double get totalMoney => cash + vcb + mb + techcombank + mbFund;
  double get totalLiquid => cash + vcb + mb + techcombank;
  double get moneyLeft => totalMoney - backupFund;

  AccountBalances copyWith({
    double? cash,
    double? vcb,
    double? mb,
    double? techcombank,
    double? mbFund,
    double? backupFund,
  }) {
    return AccountBalances(
      cash: cash ?? this.cash,
      vcb: vcb ?? this.vcb,
      mb: mb ?? this.mb,
      techcombank: techcombank ?? this.techcombank,
      mbFund: mbFund ?? this.mbFund,
      backupFund: backupFund ?? this.backupFund,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cash': cash,
      'vcb': vcb,
      'mb': mb,
      'techcombank': techcombank,
      'mbFund': mbFund,
      'backupFund': backupFund,
    };
  }

  factory AccountBalances.fromJson(Map<String, dynamic> json) {
    return AccountBalances(
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      vcb: (json['vcb'] as num?)?.toDouble() ?? 0.0,
      mb: (json['mb'] as num?)?.toDouble() ?? 0.0,
      techcombank: (json['techcombank'] as num?)?.toDouble() ?? 0.0,
      mbFund: (json['mbFund'] as num?)?.toDouble() ?? 0.0,
      backupFund: (json['backupFund'] as num?)?.toDouble() ?? 0.0,
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

  FinanceTransaction({
    required this.id,
    required this.type,
    required this.account,
    required this.amount,
    required this.date,
    required this.note,
    this.previousValue,
    this.newValue,
  });

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
    );
  }
}
