import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/services/finance_csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 10, 3, 9, 0);

  Future<FinanceProvider> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final provider = FinanceProvider(now: () => now);
    await provider.ready;
    return provider;
  }

  FinanceImport decode(String csv) {
    var next = 0;
    return FinanceCsv.decode(csv, newId: () => 'new${next++}', now: now);
  }

  /// Each record's note with the name of its Category (null: Uncategorized),
  /// looked up in [categories].
  List<(String, String?)> notesWithCategories(List<FinanceTransaction> transactions, List<Category> categories) {
    String? nameOf(String? id) {
      if (id == null) return null;
      final matches = categories.where((c) => c.id == id);
      return matches.isEmpty ? '<missing $id>' : matches.single.name;
    }

    return [for (final t in transactions) (t.note, nameOf(t.categoryId))];
  }

  Category category(String id, String name, TransactionType type) =>
      Category(id: id, name: name, type: type, createdAt: DateTime(2026, 9, 1));

  FinanceTransaction tx(String id, TransactionType type, String note, {String? categoryId, double amount = 10}) =>
      FinanceTransaction(
        id: id,
        type: type,
        account: 'Cash',
        amount: amount,
        date: DateTime(2026, 10, 1, 12),
        note: note,
        previousValue: 0,
        newValue: amount,
        categoryId: categoryId,
      );

  setUp(() => now = DateTime(2026, 10, 3, 9, 0));

  group('FinanceCsv Categories', () {
    test('Categories round-trip with new ids, and each record keeps its Category', () {
      final categories = [
        category('c1', 'Salary', TransactionType.moneyIn),
        category('c2', 'Food', TransactionType.moneyOut),
        category('c3', 'Trip, "Japan"', TransactionType.moneyOut),
      ];
      final transactions = [
        tx('a', TransactionType.moneyOut, 'Lunch', categoryId: 'c2'),
        tx('b', TransactionType.moneyOut, 'Flights', categoryId: 'c3'),
        tx('c', TransactionType.moneyIn, 'October pay', categoryId: 'c1'),
        tx('d', TransactionType.moneyOut, 'Something'),
      ];

      final result = decode(FinanceCsv.encode(AccountBalances(), transactions, [], categories: categories));

      expect(result.categories.map((c) => (c.name, c.type)), [
        ('Salary', TransactionType.moneyIn),
        ('Food', TransactionType.moneyOut),
        ('Trip, "Japan"', TransactionType.moneyOut),
      ]);
      final categoryIds = result.categories.map((c) => c.id).toList();
      expect(categoryIds.every((id) => id.startsWith('new')), true, reason: 'ids come from newId');
      expect(categoryIds.toSet(), hasLength(3));
      expect(categoryIds.any(['c1', 'c2', 'c3'].contains), false);
      expect(categoryIds.toSet().intersection(result.transactions.map((t) => t.id).toSet()), isEmpty);

      final food = result.categories.firstWhere((c) => c.name == 'Food');
      final lunch = result.transactions.firstWhere((t) => t.note == 'Lunch');
      expect(lunch.categoryId, food.id);
      expect(notesWithCategories(result.transactions, result.categories), [
        ('Lunch', 'Food'),
        ('Flights', 'Trip, "Japan"'),
        ('October pay', 'Salary'),
        ('Something', null),
      ]);
      expect(result.transactions.firstWhere((t) => t.note == 'Something').categoryId, isNull);
    });

    test('a name used for both Money In and Money Out links each record to its own type', () {
      final categories = [
        category('in', 'Other', TransactionType.moneyIn),
        category('out', 'Other', TransactionType.moneyOut),
      ];
      final transactions = [
        tx('a', TransactionType.moneyOut, 'Spent', categoryId: 'out'),
        tx('b', TransactionType.moneyIn, 'Got', categoryId: 'in'),
      ];

      final result = decode(FinanceCsv.encode(AccountBalances(), transactions, [], categories: categories));

      expect(result.categories.map((c) => (c.name, c.type)), [
        ('Other', TransactionType.moneyIn),
        ('Other', TransactionType.moneyOut),
      ]);
      Category ofType(TransactionType type) => result.categories.singleWhere((c) => c.type == type);
      expect(result.transactions.firstWhere((t) => t.note == 'Spent').categoryId, ofType(TransactionType.moneyOut).id);
      expect(result.transactions.firstWhere((t) => t.note == 'Got').categoryId, ofType(TransactionType.moneyIn).id);
    });

    test('an export made without Categories imports with every record Uncategorized', () {
      final transactions = [
        tx('a', TransactionType.moneyOut, 'Lunch'),
        tx('b', TransactionType.moneyIn, 'Pay'),
      ];

      final result = decode(FinanceCsv.encode(AccountBalances(), transactions, []));

      expect(result.categories, isEmpty);
      expect(result.transactions, hasLength(2));
      expect(result.transactions.map((t) => t.categoryId), everyElement(isNull));
    });

    test('a hand-written file in the format before Categories still imports', () {
      const csv = '--- ACCOUNT BALANCES SUMMARY ---\n'
          'Account,Amount (k VND),Amount (VND)\n'
          'Cash,10.0,10000\n'
          'VCB,0.0,0\n'
          'MB,0.0,0\n'
          'Techcombank,0.0,0\n'
          'MB investment,0.0,0\n'
          'Total Money,10.0,10000\n'
          'Fund: Rent,2.0,2000\n'
          'Funds total,2.0,2000\n'
          'Money Left,8.0,8000\n'
          '\n'
          '--- TRANSACTIONS LOG ---\n'
          'date,type,account,amount_k_vnd,amount_vnd,note,previous_value_k_vnd,new_value_k_vnd,datetime\n'
          '2026-10-01,moneyIn,Cash,12.0,12000,Salary,0.0,12.0,2026-10-01T08:00:00.000\n'
          '2026-10-02,moneyOut,Cash,2.0,2000,Lunch,12.0,10.0,2026-10-02T12:00:00.000\n';

      final result = decode(csv);

      expect(result.categories, isEmpty);
      expect(result.funds.single.name, 'Rent');
      expect(result.transactions.map((t) => t.note), ['Salary', 'Lunch']);
      expect(result.transactions.map((t) => t.categoryId), everyElement(isNull));
    });

    test('amounts with five decimals survive the round-trip exactly', () {
      final balances = AccountBalances(cash: 12.34567, vcb: 1.00001);
      final funds = [Fund(id: 'f', name: 'Small', amount: 12.34567, createdAt: DateTime(2026))];
      final transactions = [
        FinanceTransaction(
          id: 'a',
          type: TransactionType.moneyOut,
          account: 'Cash',
          amount: 12.34567,
          date: DateTime(2026, 10, 1, 12),
          note: 'Precise',
          previousValue: 24.69134,
          newValue: 12.34567,
          categoryId: 'c',
        ),
      ];
      final categories = [category('c', 'Food', TransactionType.moneyOut)];

      final result = decode(FinanceCsv.encode(balances, transactions, funds, categories: categories));

      expect(result.balances.cash, 12.34567);
      expect(result.balances.vcb, 1.00001);
      expect(result.funds.single.amount, 12.34567);
      final t = result.transactions.single;
      expect(t.amount, 12.34567);
      expect(t.previousValue, 24.69134);
      expect(t.newValue, 12.34567);
      expect(t.categoryId, result.categories.single.id);
    });
  });

  group('FinanceProvider Categories import', () {
    String export(FinanceProvider p) =>
        FinanceCsv.encode(p.balances, p.transactions, p.funds, categories: p.categories);

    String? categoryName(FinanceProvider p, FinanceTransaction t) => p.categoryById(t.categoryId)?.name;

    test('Categories and each record\'s Category survive export, import and a reload', () async {
      final source = await fresh();
      expect(await source.addCategory(name: 'Salary', type: TransactionType.moneyIn), isNull);
      expect(await source.addCategory(name: 'Food', type: TransactionType.moneyOut), isNull);
      expect(await source.addCategory(name: 'Trip, "Japan"', type: TransactionType.moneyOut), isNull);
      final salary = source.categoriesFor(TransactionType.moneyIn).single;
      final [food, trip] = source.categoriesFor(TransactionType.moneyOut);
      await source.recordMoneyIn(account: 'Cash', amount: 500, date: DateTime(2026, 10, 1), note: 'Pay', categoryId: salary.id);
      now = now.add(const Duration(minutes: 1));
      await source.recordMoneyOut(account: 'Cash', amount: 20, date: DateTime(2026, 10, 2), note: 'Lunch', categoryId: food.id);
      now = now.add(const Duration(minutes: 1));
      await source.recordMoneyOut(account: 'Cash', amount: 200, date: DateTime(2026, 10, 2), note: 'Flights', categoryId: trip.id);
      now = now.add(const Duration(minutes: 1));
      await source.recordMoneyOut(account: 'Cash', amount: 5, date: DateTime(2026, 10, 3), note: 'Snack');
      final expected = [for (final t in source.transactions) (t.note, categoryName(source, t))];
      expect(expected, [('Snack', null), ('Flights', 'Trip, "Japan"'), ('Lunch', 'Food'), ('Pay', 'Salary')]);
      final csv = export(source);

      final target = await fresh();
      await target.importData(target.readCsvExport(csv));

      expect(target.categoriesFor(TransactionType.moneyOut).map((c) => c.name), ['Food', 'Trip, "Japan"']);
      expect(target.categoriesFor(TransactionType.moneyIn).map((c) => c.name), ['Salary']);
      expect([for (final t in target.transactions) (t.note, categoryName(target, t))], expected);

      final reloaded = FinanceProvider(now: () => now);
      await reloaded.ready;
      expect(reloaded.categoriesFor(TransactionType.moneyOut).map((c) => c.name), ['Food', 'Trip, "Japan"']);
      expect(reloaded.categoriesFor(TransactionType.moneyIn).map((c) => c.name), ['Salary']);
      expect([for (final t in reloaded.transactions) (t.note, categoryName(reloaded, t))], expected);
    });

    test('a Category in Trash is not exported', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: TransactionType.moneyOut);
      await provider.addCategory(name: 'Gone', type: TransactionType.moneyOut);
      final gone = provider.categoriesFor(TransactionType.moneyOut).firstWhere((c) => c.name == 'Gone');
      await provider.deleteCategory(gone.id);

      final result = decode(export(provider));

      expect(result.categories.map((c) => c.name), ['Food']);
    });

    test('importing replaces the existing Categories with the imported ones', () async {
      final source = await fresh();
      await source.addCategory(name: 'Food', type: TransactionType.moneyOut);
      final csv = export(source);

      final target = await fresh();
      await target.addCategory(name: 'Old in', type: TransactionType.moneyIn);
      await target.addCategory(name: 'Old out', type: TransactionType.moneyOut);
      await target.importData(target.readCsvExport(csv));

      expect(target.categories.map((c) => (c.name, c.type)), [('Food', TransactionType.moneyOut)]);
      expect(target.categoriesFor(TransactionType.moneyIn), isEmpty);
    });

    test('a file exported before Categories imports with no Categories and every record Uncategorized', () async {
      final source = await fresh();
      await source.recordMoneyIn(account: 'Cash', amount: 50, date: DateTime(2026, 10, 1), note: 'Pay');
      await source.recordMoneyOut(account: 'Cash', amount: 5, date: DateTime(2026, 10, 2), note: 'Lunch');
      final csv = FinanceCsv.encode(source.balances, source.transactions, source.funds);

      final target = await fresh();
      await target.addCategory(name: 'Old', type: TransactionType.moneyOut);
      await target.importData(target.readCsvExport(csv));

      expect(target.categories, isEmpty);
      expect(target.transactions, hasLength(2));
      expect(target.transactions.map((t) => t.categoryId), everyElement(isNull));
    });
  });
}
