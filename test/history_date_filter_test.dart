import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/screens/history_filters_screen.dart';
import 'package:mix_app/screens/transaction_history_screen.dart';
import 'package:mix_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHistory(WidgetTester tester, FinanceProvider finance) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: finance,
        child: const MaterialApp(home: TransactionHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The history keeps the last filter for the app's lifetime; start clean.
    if (find.text('Reset Filters').evaluate().isNotEmpty) {
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Filters button lays out and opens under the real app theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() => finance.ready);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: finance,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const TransactionHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Filters'), findsOneWidget);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryFiltersScreen), findsOneWidget);
  });

  testWidgets('Filters page: This month applies with "Show 1 record", and Reset Filters returns to all', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime.now(), note: 'Today');
      await finance.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime(2020, 1, 1), note: 'Long ago');
    });

    await pumpHistory(tester, finance);
    expect(find.text('Showing 2 of 2 records'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryFiltersScreen), findsOneWidget);
    expect(find.text('Show 2 records'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 1 record'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryFiltersScreen), findsNothing);
    expect(find.text('Showing 1 of 2 records'), findsOneWidget);
    expect(find.text('Filters · 1'), findsOneWidget);

    await tester.tap(find.text('Reset Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 2 of 2 records'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Filters · 1'), findsNothing);
  });

  testWidgets('filtering by a Category shows only its records, and the summary totals it by Category', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.updateAccountField('Cash', 500);
      await finance.addCategory(name: 'Food', type: TransactionType.moneyOut);
      final food = finance.categories.firstWhere((c) => c.name == 'Food').id;
      await finance.recordMoneyOut(account: 'Cash', amount: 50, date: DateTime.now(), note: 'Dinner', categoryId: food);
      await finance.recordMoneyOut(account: 'Cash', amount: 30, date: DateTime.now(), note: 'Taxi');
    });

    await pumpHistory(tester, finance);
    expect(find.text('Showing 3 of 3 records'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    final foodBox = find.widgetWithText(CheckboxListTile, 'Food');
    await tester.scrollUntilVisible(foodBox, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(foodBox);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 1 record'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 3 records'), findsOneWidget);
    expect(find.text('Filters · 1'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Taxi'), findsNothing);

    await tester.tap(find.text('Tap for totals by category'));
    await tester.pumpAndSettle();
    expect(find.text('MONEY OUT BY CATEGORY'), findsOneWidget);
    final moneyOutBreakdown = find.ancestor(of: find.text('MONEY OUT BY CATEGORY'), matching: find.byType(Column)).first;
    final foodRow = find.ancestor(
      of: find.descendant(of: moneyOutBreakdown, matching: find.text('Food')),
      matching: find.byType(Row),
    );
    expect(find.descendant(of: foodRow, matching: find.text('50,000 VND')), findsOneWidget);
    expect(find.descendant(of: moneyOutBreakdown, matching: find.text('Uncategorized')), findsNothing);
  });
}
