import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/budget/budget_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('Budget editor fits a narrow phone and keeps actions visible', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const [
          'A household category with an exceptionally long display name',
        ],
        existingBudgets: const {'Food': 1250, 'Transport': 800},
        transactions: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Budgets'), findsWidgets);
    expect(find.text('Monthly plan'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-total-summary')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save Budgets'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-clear-month')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('budget-form-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Save Budgets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Budget totals and custom categories update locally', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const [],
        existingBudgets: const {'Food': 1250},
        transactions: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('budget-amount-Food')),
      '2500',
    );
    await tester.enterText(
      find.byKey(const ValueKey('budget-new-category')),
      'Family travel and holidays',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('budget-amount-Family travel and holidays')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Budget editor catches duplicate categories and invalid amounts',
    (tester) async {
      await _pumpOnPhone(
        tester,
        BudgetEntrySheet(
          month: DateTime(2026, 7),
          categories: const [],
          existingBudgets: const {'Food': 1250},
          transactions: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('budget-new-category')),
        'food',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('This category already exists.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('budget-amount-Food')),
        '-10',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Budgets'));
      await tester.pumpAndSettle();

      expect(find.text('Check the amount for Food.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Clear month keeps its confirmation safeguard', (tester) async {
    await _pumpOnPhone(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const [],
        existingBudgets: const {'Food': 1250},
        transactions: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('budget-clear-month')));
    await tester.pumpAndSettle();

    expect(find.text('Clear Month Budgets?'), findsOneWidget);
    expect(
      find.text(
        'Remove every category budget for July 2026? This cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(OutlinedButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear Month Budgets?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Suggest fills budget fields from real spending history', (
    tester,
  ) async {
    final transactions = [
      _tx(
        id: 'income',
        type: 'income',
        amount: 60000,
        daysAgo: 25,
        toAccount: true,
      ),
      for (var i = 1; i <= 30; i++)
        _tx(
          id: 'e$i',
          type: 'expense',
          amount: 500,
          daysAgo: i,
          category: 'Food',
        ),
    ];

    await _pumpOnPhone(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const ['Food'],
        existingBudgets: const {},
        transactions: transactions,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('budget-suggest')));
    await tester.pumpAndSettle();

    final foodField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('budget-amount-Food')),
    );
    expect(foodField.controller?.text, '15000');
    expect(find.textContaining('already keep you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Suggest shows a notice instead of guessing without enough history',
    (tester) async {
      await _pumpOnPhone(
        tester,
        BudgetEntrySheet(
          month: DateTime(2026, 7),
          categories: const [],
          existingBudgets: const {},
          transactions: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('budget-suggest')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not enough history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Budget helper opens the editor as a full-page route', (
    tester,
  ) async {
    bool? result;
    await _pumpOnPhone(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showBudgetEntrySheet(
                  context: context,
                  month: DateTime(2026, 7),
                  categories: const [],
                  existingBudgets: const {},
                  transactions: const [],
                );
              },
              child: const Text('Open budgets'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open budgets'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly plan'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Open budgets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOnPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
}

TransactionRecord _tx({
  required String id,
  required String type,
  required double amount,
  required int daysAgo,
  bool toAccount = false,
  String? category,
}) {
  final date = DateTime.now().subtract(Duration(days: daysAgo));
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    toAccountId: toAccount ? 'account-1' : null,
    fromAccountId: toAccount ? null : 'account-1',
    category: category,
    occurredAt: date,
    createdAt: date,
  );
}
