import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/screens/money_transaction_screen.dart';
import 'package:mix_app/widgets/category_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<FinanceProvider> freshProvider(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.updateAccountField('Cash', 500);
    });
    return finance;
  }

  /// A home page that pushes the Money Out form, so recording it can pop.
  Future<void> openMoneyOut(WidgetTester tester, FinanceProvider finance) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: finance,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoneyTransactionScreen(isMoneyIn: false)),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(MoneyTransactionScreen), findsOneWidget);
  }

  Finder pickerShows(String label) => find.descendant(of: find.byType(CategoryPicker), matching: find.text(label));

  Future<void> chooseNewCategory(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CategoryPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CategoryPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category').last);
    await tester.pumpAndSettle();
    expect(find.text('New Money Out category'), findsOneWidget);
  }

  testWidgets('cancelling "+ New category" goes back to the previous choice', (tester) async {
    final finance = await freshProvider(tester);
    await openMoneyOut(tester, finance);
    expect(pickerShows('Uncategorized'), findsOneWidget);

    await chooseNewCategory(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(pickerShows('Uncategorized'), findsOneWidget);
    expect(pickerShows('New category'), findsNothing);
    expect(finance.categories, isEmpty);
  });

  testWidgets('saving a new Category selects it, and the Money Out is recorded with it', (tester) async {
    final finance = await freshProvider(tester);
    await openMoneyOut(tester, finance);

    await chooseNewCategory(tester);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Food');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(pickerShows('Food'), findsOneWidget);
    expect(pickerShows('New category'), findsNothing);
    final food = finance.categories.single;
    expect(food.name, 'Food');
    expect(food.type, TransactionType.moneyOut);

    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter reason or note...'), 'Dinner');
    await tester.ensureVisible(find.text('Record Money Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Money Out'));
    await tester.pumpAndSettle();

    expect(find.byType(MoneyTransactionScreen), findsNothing);
    final dinner = finance.transactions.singleWhere((t) => t.note == 'Dinner');
    expect(dinner.type, TransactionType.moneyOut);
    expect(dinner.amount, 50.0);
    expect(dinner.categoryId, food.id);
    expect(finance.balances.cash, 450.0);
  });
}
