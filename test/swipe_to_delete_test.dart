import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/providers/settings_provider.dart';
import 'package:mix_app/screens/finance_screen.dart';
import 'package:mix_app/widgets/finance_transaction_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('swiping a Recent Transactions tile asks first: Cancel keeps it, Confirm moves it to Trash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.updateAccountField('Cash', 500);
      await finance.recordMoneyOut(account: 'Cash', amount: 80, date: DateTime(2026, 9, 1), note: 'Dinner');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider.value(value: finance),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final dinnerTile = find.widgetWithText(FinanceTransactionTile, 'Dinner');
    expect(dinnerTile, findsOneWidget);

    await tester.drag(dinnerTile, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsNothing);
    expect(dinnerTile, findsOneWidget);
    expect(tester.getTopLeft(dinnerTile).dx, tester.getTopLeft(find.byType(FinanceTransactionTile).last).dx);
    expect(finance.trash, isEmpty);
    expect(finance.balances.cash, 420.0);

    await tester.drag(dinnerTile, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(dinnerTile, findsNothing);
    expect(finance.trash.single.transaction!.note, 'Dinner');
    expect(finance.balances.cash, 500.0);
  });
}
