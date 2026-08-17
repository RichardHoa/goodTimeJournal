import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/screens/transaction_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('one date pill opens the presets sheet, and Reset filters returns to All time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime.now(), note: 'Today');
      await finance.recordMoneyIn(account: 'Cash', amount: 10, date: DateTime(2020, 1, 1), note: 'Long ago');
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: finance,
        child: const MaterialApp(home: TransactionHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Showing 2 of 2 records'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    for (final option in ['All time', 'Today', 'This week', 'This month', 'Pick range…']) {
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(option)), findsOneWidget, reason: option);
    }

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('This month')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Showing 1 of 2 records'), findsOneWidget);

    await tester.tap(find.text('Reset Filters'));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Showing 2 of 2 records'), findsOneWidget);
  });
}
