import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = TransactionType.moneyOut;
const _in = TransactionType.moneyIn;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 9, 1, 10, 30);

  Future<FinanceProvider> load() async {
    final provider = FinanceProvider(now: () => now);
    await provider.ready;
    return provider;
  }

  Future<FinanceProvider> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return load();
  }

  setUp(() => now = DateTime(2026, 9, 1, 10, 30));

  /// Moves the clock on so the next id/creation time is distinct.
  void tick() => now = now.add(const Duration(minutes: 1));

  String idOf(FinanceProvider p, TransactionType type, String name) =>
      p.categoriesFor(type).firstWhere((c) => c.name == name).id;

  FinanceTransaction byNote(FinanceProvider p, String note) =>
      p.transactions.firstWhere((t) => t.note == note);

  group('Categories', () {
    test('Money In and Money Out each list their own Categories in creation order', () async {
      final provider = await fresh();
      expect(provider.categories, isEmpty);
      expect(provider.categoriesFor(_out), isEmpty);
      expect(provider.categoriesFor(_in), isEmpty);

      expect(await provider.addCategory(name: 'Food', type: _out), isNull);
      tick();
      expect(await provider.addCategory(name: 'Salary', type: _in), isNull);
      tick();
      expect(await provider.addCategory(name: 'Rent', type: _out), isNull);
      tick();
      expect(await provider.addCategory(name: 'Gifts', type: _in), isNull);

      expect(provider.categoriesFor(_out).map((c) => c.name), ['Food', 'Rent']);
      expect(provider.categoriesFor(_in).map((c) => c.name), ['Salary', 'Gifts']);
      expect(provider.categoriesFor(_out).every((c) => c.type == _out), isTrue);
      expect(provider.categories.length, 4);
    });

    test('names are required, trimmed and unique within a type ignoring case', () async {
      final provider = await fresh();
      expect(await provider.addCategory(name: 'Food', type: _out), isNull);

      expect(await provider.addCategory(name: '   ', type: _out), isNotNull);
      expect(provider.validateCategoryName('', _out), isNotNull);
      expect(await provider.addCategory(name: '  food ', type: _out), isNotNull);
      expect(provider.validateCategoryName('FOOD', _out), isNotNull);
      expect(provider.categoriesFor(_out).map((c) => c.name), ['Food']);

      // The same name is fine for the other type.
      expect(provider.validateCategoryName('Food', _in), isNull);
      expect(await provider.addCategory(name: 'Other', type: _out), isNull);
      expect(await provider.addCategory(name: 'Other', type: _in), isNull);

      expect(await provider.addCategory(name: '  Travel  ', type: _out), isNull);
      expect(provider.categoriesFor(_out).map((c) => c.name), ['Food', 'Other', 'Travel']);
      expect(provider.categoriesFor(_in).map((c) => c.name), ['Other']);
    });

    test('a Money Out keeps a Money Out Category; a Money In or unknown Category is ignored', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      await provider.addCategory(name: 'Salary', type: _in);
      final food = idOf(provider, _out, 'Food');
      final salary = idOf(provider, _in, 'Salary');

      await provider.recordMoneyOut(
          account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      await provider.recordMoneyOut(
          account: 'Cash', amount: 20, date: DateTime(2026, 9, 1), note: 'Wrong type', categoryId: salary);
      await provider.recordMoneyOut(
          account: 'Cash', amount: 10, date: DateTime(2026, 9, 1), note: 'Unknown', categoryId: 'no-such-id');
      await provider.recordMoneyIn(
          account: 'VCB', amount: 1000, date: DateTime(2026, 9, 1), note: 'Pay', categoryId: salary);

      expect(byNote(provider, 'Lunch').categoryId, food);
      expect(provider.categoryById(byNote(provider, 'Lunch').categoryId)!.name, 'Food');
      expect(byNote(provider, 'Wrong type').categoryId, isNull);
      expect(byNote(provider, 'Unknown').categoryId, isNull);
      expect(byNote(provider, 'Pay').categoryId, salary);
      expect(provider.balances.cash, -60.0);
    });

    test('renaming a Category shows the new name on its records; taken names are rejected', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      await provider.addCategory(name: 'Rent', type: _out);
      await provider.addCategory(name: 'Snacks', type: _in);
      final food = idOf(provider, _out, 'Food');
      await provider.recordMoneyOut(
          account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);

      expect(await provider.renameCategory(food, 'Eating out'), isNull);
      final lunch = byNote(provider, 'Lunch');
      expect(lunch.categoryId, food);
      expect(provider.categoryById(lunch.categoryId)!.name, 'Eating out');

      expect(await provider.renameCategory(food, 'rent'), isNotNull);
      expect(await provider.renameCategory(food, '   '), isNotNull);
      expect(provider.categoryById(food)!.name, 'Eating out');

      // A Money In Category's name doesn't block a Money Out one.
      expect(await provider.renameCategory(food, 'Snacks'), isNull);
      // Keeping its own name in another case is fine.
      expect(await provider.renameCategory(food, ' SNACKS '), isNull);
      expect(provider.categoryById(food)!.name, 'SNACKS');
    });

    test('usage counts the live records using a Category', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      await provider.addCategory(name: 'Rent', type: _out);
      final food = idOf(provider, _out, 'Food');
      final rent = idOf(provider, _out, 'Rent');

      await provider.recordMoneyOut(account: 'Cash', amount: 1, date: DateTime(2026, 9, 1), note: 'a', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 2, date: DateTime(2026, 9, 1), note: 'b', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 3, date: DateTime(2026, 9, 1), note: 'c', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 4, date: DateTime(2026, 9, 1), note: 'd');

      expect(provider.categoryUsage(food), 3);
      expect(provider.categoryUsage(rent), 0);

      await provider.deleteTransaction(byNote(provider, 'b').id);
      expect(provider.categoryUsage(food), 2);
    });

    test('deleting a Category sends it to Trash and leaves its records Uncategorized', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      await provider.addCategory(name: 'Rent', type: _out);
      final food = idOf(provider, _out, 'Food');
      final rent = idOf(provider, _out, 'Rent');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 20, date: DateTime(2026, 9, 1), note: 'Dinner', categoryId: food);
      await provider.recordMoneyOut(account: 'MB', amount: 300, date: DateTime(2026, 9, 1), note: 'Flat', categoryId: rent);

      await provider.deleteCategory(food);

      expect(provider.categoriesFor(_out).map((c) => c.name), ['Rent']);
      expect(provider.categoryById(food), isNull);
      final item = provider.trash.single;
      expect(item.kind, TrashKind.category);
      expect(item.category!.name, 'Food');
      expect(byNote(provider, 'Lunch').categoryId, isNull);
      expect(byNote(provider, 'Dinner').categoryId, isNull);
      expect(byNote(provider, 'Flat').categoryId, rent);
      expect(provider.transactions.length, 3);
      expect(provider.balances.cash, -50.0);
      expect(provider.balances.mb, -300.0);
    });

    test('restoring a Category gives it back to its records, unless they were re-categorised', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      tick();
      await provider.addCategory(name: 'Snacks', type: _out);
      final food = idOf(provider, _out, 'Food');
      final snacks = idOf(provider, _out, 'Snacks');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 5, date: DateTime(2026, 9, 1), note: 'Chips', categoryId: food);
      await provider.recordMoneyOut(account: 'Cash', amount: 7, date: DateTime(2026, 9, 1), note: 'Bus');

      await provider.deleteCategory(food);
      final chips = byNote(provider, 'Chips');
      await provider.updateTransaction(
        id: chips.id,
        newAccount: 'Cash',
        newAmount: 5,
        newDate: chips.date,
        newNote: 'Chips',
        newCategoryId: snacks,
      );

      expect(await provider.restoreFromTrash(provider.trash.single.id), isNull);

      expect(provider.trash, isEmpty);
      expect(provider.categoriesFor(_out).map((c) => c.name), ['Food', 'Snacks']);
      expect(byNote(provider, 'Lunch').categoryId, food);
      expect(byNote(provider, 'Chips').categoryId, snacks);
      expect(byNote(provider, 'Bus').categoryId, isNull);
      expect(provider.categoryUsage(food), 1);
      expect(provider.balances.cash, -42.0);
    });

    test('restoring a Category is blocked when its name was taken meanwhile', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      final food = idOf(provider, _out, 'Food');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      await provider.deleteCategory(food);
      tick();
      await provider.addCategory(name: 'FOOD', type: _out);

      final error = await provider.restoreFromTrash(provider.trash.single.id);

      expect(error, isNotNull);
      expect(provider.trash.single.kind, TrashKind.category);
      expect(provider.categoriesFor(_out).map((c) => c.name), ['FOOD']);
      expect(byNote(provider, 'Lunch').categoryId, isNull);
    });

    test('a Money In Category of the same name does not block restoring a Money Out one', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Other', type: _out);
      await provider.deleteCategory(idOf(provider, _out, 'Other'));
      await provider.addCategory(name: 'Other', type: _in);

      expect(await provider.restoreFromTrash(provider.trash.single.id), isNull);
      expect(provider.categoriesFor(_out).map((c) => c.name), ['Other']);
      expect(provider.categoriesFor(_in).map((c) => c.name), ['Other']);
    });

    test('Categories, record Categories and trashed Categories survive a reload', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      tick();
      await provider.addCategory(name: 'Salary', type: _in);
      tick();
      await provider.addCategory(name: 'Rent', type: _out);
      final food = idOf(provider, _out, 'Food');
      final salary = idOf(provider, _in, 'Salary');
      final rent = idOf(provider, _out, 'Rent');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      await provider.recordMoneyIn(account: 'VCB', amount: 900, date: DateTime(2026, 9, 1), note: 'Pay', categoryId: salary);
      await provider.recordMoneyOut(account: 'MB', amount: 300, date: DateTime(2026, 9, 1), note: 'Flat', categoryId: rent);
      await provider.deleteCategory(rent);

      final reloaded = await load();

      expect(reloaded.categoriesFor(_out).map((c) => c.name), ['Food']);
      expect(reloaded.categoriesFor(_in).map((c) => c.name), ['Salary']);
      expect(byNote(reloaded, 'Lunch').categoryId, food);
      expect(byNote(reloaded, 'Pay').categoryId, salary);
      expect(byNote(reloaded, 'Flat').categoryId, isNull);
      expect(reloaded.trash.single.kind, TrashKind.category);
      expect(reloaded.trash.single.category!.name, 'Rent');

      expect(await reloaded.restoreFromTrash(reloaded.trash.single.id), isNull);
      expect(byNote(reloaded, 'Flat').categoryId, rent);
      expect(reloaded.categoriesFor(_out).map((c) => c.name), ['Food', 'Rent']);
    });

    test('editing a record can change or clear its Category, never its type', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      await provider.addCategory(name: 'Rent', type: _out);
      final food = idOf(provider, _out, 'Food');
      final rent = idOf(provider, _out, 'Rent');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);
      final lunch = byNote(provider, 'Lunch');

      await provider.updateTransaction(
        id: lunch.id,
        newAccount: 'Cash',
        newAmount: 30,
        newDate: lunch.date,
        newNote: 'Lunch',
        newCategoryId: rent,
      );
      expect(byNote(provider, 'Lunch').categoryId, rent);
      expect(byNote(provider, 'Lunch').type, _out);

      await provider.updateTransaction(
        id: lunch.id,
        newAccount: 'Cash',
        newAmount: 30,
        newDate: lunch.date,
        newNote: 'Lunch',
        newCategoryId: null,
      );
      expect(byNote(provider, 'Lunch').categoryId, isNull);
      expect(byNote(provider, 'Lunch').type, _out);
      expect(provider.balances.cash, -30.0);
    });

    test('a restored Money Out whose Category is gone comes back Uncategorized', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      final food = idOf(provider, _out, 'Food');
      await provider.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime(2026, 9, 1), note: 'Lunch', categoryId: food);

      await provider.deleteTransaction(byNote(provider, 'Lunch').id);
      tick();
      await provider.deleteCategory(food);
      final txItem = provider.trash.firstWhere((i) => i.kind == TrashKind.transaction);

      expect(await provider.restoreFromTrash(txItem.id), isNull);

      expect(byNote(provider, 'Lunch').categoryId, isNull);
      expect(provider.balances.cash, -30.0);
    });
  });

  group('Ordering', () {
    test('records are kept newest date first as they are recorded and edited', () async {
      final provider = await fresh();
      await provider.recordMoneyOut(account: 'Cash', amount: 10, date: DateTime(2026, 9, 1), note: 'Today');
      tick();
      await provider.recordMoneyOut(account: 'Cash', amount: 10, date: DateTime(2026, 8, 20), note: 'Earlier');
      expect(provider.transactions.map((t) => t.note), ['Today', 'Earlier']);

      tick();
      await provider.recordMoneyOut(account: 'Cash', amount: 10, date: DateTime(2026, 9, 5), note: 'Later');
      expect(provider.transactions.map((t) => t.note), ['Later', 'Today', 'Earlier']);

      final earlier = byNote(provider, 'Earlier');
      await provider.updateTransaction(
        id: earlier.id,
        newAccount: 'Cash',
        newAmount: 10,
        newDate: DateTime(2026, 9, 10, 9),
        newNote: 'Earlier',
      );
      expect(provider.transactions.map((t) => t.note), ['Earlier', 'Later', 'Today']);
    });
  });

  group('Explaining a balance change', () {
    test('a fall is split into the typed Money Out entries plus a Balance adjustment for the rest', () async {
      final provider = await fresh();
      await provider.addCategory(name: 'Food', type: _out);
      final food = idOf(provider, _out, 'Food');
      await provider.updateAccountField('MB', 5500);
      final before = provider.transactions.length;
      tick();

      await provider.explainBalanceChange(
        account: 'MB',
        newBalance: 5000,
        entries: [
          BalanceChangeEntry(amount: 300, note: 'Rent', date: DateTime(2026, 8, 28), categoryId: food),
          BalanceChangeEntry(amount: 150, note: 'Lunch', date: DateTime(2026, 8, 30)),
        ],
      );

      expect(provider.balances.mb, 5000.0);
      final added = provider.transactions.length - before;
      expect(added, 3);
      final rent = byNote(provider, 'Rent');
      expect(rent.type, _out);
      expect(rent.account, 'MB');
      expect(rent.amount, 300.0);
      expect(rent.categoryId, food);
      expect([rent.date.year, rent.date.month, rent.date.day], [2026, 8, 28]);
      final lunch = byNote(provider, 'Lunch');
      expect(lunch.type, _out);
      expect(lunch.amount, 150.0);
      expect(lunch.categoryId, isNull);
      expect([lunch.date.year, lunch.date.month, lunch.date.day], [2026, 8, 30]);
      final adjustments = provider.transactions
          .where((t) => t.note == FinanceProvider.balanceAdjustmentNote && t.type == _out)
          .toList();
      expect(adjustments.single.amount, 50.0);
      expect(adjustments.single.account, 'MB');
    });

    test('entries that explain the whole change leave no Balance adjustment', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB', 5500);
      final before = provider.transactions.length;

      await provider.explainBalanceChange(
        account: 'MB',
        newBalance: 5000,
        entries: [
          BalanceChangeEntry(amount: 300, note: 'Rent', date: DateTime(2026, 8, 28)),
          BalanceChangeEntry(amount: 200, note: 'Lunch', date: DateTime(2026, 8, 30)),
        ],
      );

      expect(provider.balances.mb, 5000.0);
      expect(provider.transactions.length - before, 2);
      expect(provider.transactions.where((t) => t.type == _out && t.note == FinanceProvider.balanceAdjustmentNote),
          isEmpty);
    });

    test('a rise is split into Money In entries plus a Money In Balance adjustment', () async {
      final provider = await fresh();
      await provider.updateAccountField('Cash', 100);
      final before = provider.transactions.length;
      tick();

      await provider.explainBalanceChange(
        account: 'Cash',
        newBalance: 400,
        entries: [
          BalanceChangeEntry(amount: 200, note: 'Gift', date: DateTime(2026, 8, 31)),
          BalanceChangeEntry(amount: 50, note: 'Refund', date: DateTime(2026, 9, 1)),
        ],
      );

      expect(provider.balances.cash, 400.0);
      expect(provider.transactions.length - before, 3);
      expect(byNote(provider, 'Gift').type, _in);
      expect(byNote(provider, 'Gift').amount, 200.0);
      expect(byNote(provider, 'Refund').type, _in);
      expect(byNote(provider, 'Refund').amount, 50.0);
      // The earlier 100 Balance adjustment is told apart by its amount.
      final newAdjustments = provider.transactions
          .where((t) => t.note == FinanceProvider.balanceAdjustmentNote && t.amount == 50.0)
          .toList();
      expect(newAdjustments.single.type, _in);
      expect(newAdjustments.single.account, 'Cash');
    });

    test('with no entries the whole change is one Balance adjustment', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB', 5500);
      tick();

      await provider.explainBalanceChange(account: 'MB', newBalance: 5000, entries: const []);

      expect(provider.balances.mb, 5000.0);
      expect(provider.transactions.length, 2);
      final adjustment = provider.transactions.firstWhere((t) => t.type == _out);
      expect(adjustment.amount, 500.0);
      expect(adjustment.note, FinanceProvider.balanceAdjustmentNote);
      expect(adjustment.account, 'MB');
    });

    test('entries adding up to more than the change are recorded as typed, ending past the new balance', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB', 5500);
      final before = provider.transactions.length;

      await provider.explainBalanceChange(
        account: 'MB',
        newBalance: 5000,
        entries: [
          BalanceChangeEntry(amount: 400, note: 'Rent', date: DateTime(2026, 8, 28)),
          BalanceChangeEntry(amount: 200, note: 'Lunch', date: DateTime(2026, 8, 30)),
        ],
      );

      expect(provider.transactions.length - before, 2);
      expect(byNote(provider, 'Rent').amount, 400.0);
      expect(byNote(provider, 'Lunch').amount, 200.0);
      expect(provider.balances.mb, 4900.0);
    });

    test('no change records nothing, and MB investment is not accepted', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB', 5500);
      await provider.updateAccountField('MB investment', 1000);
      final before = provider.transactions.length;

      await provider.explainBalanceChange(
        account: 'MB',
        newBalance: 5500,
        entries: [BalanceChangeEntry(amount: 100, note: 'Rent', date: DateTime(2026, 8, 28))],
      );
      expect(provider.transactions.length, before);
      expect(provider.balances.mb, 5500.0);

      await provider.explainBalanceChange(
        account: 'MB investment',
        newBalance: 800,
        entries: [BalanceChangeEntry(amount: 100, note: 'Loss', date: DateTime(2026, 8, 28))],
      );
      expect(provider.transactions.length, before);
      expect(provider.balances.mbInvestment, 1000.0);
    });

    test('5-decimal amounts are recorded exactly', () async {
      final provider = await fresh();
      await provider.updateAccountField('Cash', 10);
      tick();

      await provider.explainBalanceChange(account: 'Cash', newBalance: 9.99999, entries: const []);

      expect(provider.balances.cash, closeTo(9.99999, 1e-9));
      final adjustment = provider.transactions.firstWhere((t) => t.type == _out);
      expect(adjustment.amount, closeTo(0.00001, 1e-9));
      expect(adjustment.note, FinanceProvider.balanceAdjustmentNote);
    });

    test('deleting one split entry afterwards trashes it and gives its amount back', () async {
      final provider = await fresh();
      await provider.updateAccountField('MB', 5500);
      await provider.explainBalanceChange(
        account: 'MB',
        newBalance: 5000,
        entries: [
          BalanceChangeEntry(amount: 300, note: 'Rent', date: DateTime(2026, 8, 28)),
          BalanceChangeEntry(amount: 150, note: 'Lunch', date: DateTime(2026, 8, 30)),
        ],
      );

      final lunch = byNote(provider, 'Lunch');
      await provider.deleteTransaction(lunch.id);

      expect(provider.balances.mb, 5150.0);
      expect(provider.trash.single.kind, TrashKind.transaction);
      expect(provider.trash.single.transaction!.id, lunch.id);
      expect(provider.transactions.where((t) => t.note == 'Lunch'), isEmpty);
    });
  });
}
