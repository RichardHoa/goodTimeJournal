import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix_app/models/finance_model.dart';
import 'package:mix_app/providers/finance_provider.dart';
import 'package:mix_app/screens/balance_change_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<FinanceProvider> cashAt100(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final finance = FinanceProvider();
    await tester.runAsync(() async {
      await finance.ready;
      await finance.updateAccountField('Cash', 100);
    });
    return finance;
  }

  /// A home page that pushes the screen, so its Save can pop.
  Future<void> openScreen(WidgetTester tester, FinanceProvider finance) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: finance,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BalanceChangeScreen(account: 'Cash', newBalance: 60)),
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
    expect(find.byType(BalanceChangeScreen), findsOneWidget);
  }

  List<FinanceTransaction> moneyOut(FinanceProvider finance) =>
      finance.transactions.where((t) => t.type == TransactionType.moneyOut).toList();

  testWidgets('an entry explains part of the fall; the rest becomes a Balance adjustment', (tester) async {
    final finance = await cashAt100(tester);
    await openScreen(tester, finance);

    expect(find.text('Money Out to explain: 40,000 VND'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '10+5');
    await tester.enterText(fields.at(1), 'Lunch');
    await tester.pumpAndSettle();
    expect(find.text('25,000 VND'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(BalanceChangeScreen), findsNothing);
    expect(finance.balances.cash, 60.0);
    final outs = moneyOut(finance);
    expect(outs, hasLength(2));
    expect(outs.where((t) => t.amount == 15 && t.note == 'Lunch'), hasLength(1));
    expect(outs.where((t) => t.amount == 25 && t.note == FinanceProvider.balanceAdjustmentNote), hasLength(1));
  });

  testWidgets('entries over the change ask first; Save anyway records them as typed', (tester) async {
    final finance = await cashAt100(tester);
    await openScreen(tester, finance);

    await tester.enterText(find.byType(TextFormField).at(0), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('will end at 50,000 VND, not 60,000 VND.')), findsOneWidget);

    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();

    expect(find.byType(BalanceChangeScreen), findsNothing);
    expect(finance.balances.cash, 50.0);
    final outs = moneyOut(finance);
    expect(outs, hasLength(1));
    expect(outs.single.amount, 50.0);
  });
}
