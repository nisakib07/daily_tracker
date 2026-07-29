import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_master/data/ai_service.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders Money In form fields', (tester) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.income,
        accounts: _accountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Income'), findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('To account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('renders Money Out form fields', (tester) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.expense,
        accounts: _accountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('From account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('renders Transfer form fields', (tester) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.transfer,
        accounts: _accountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transfer'), findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('From account'), findsOneWidget);
    expect(find.text('To account'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('Quick add shortcuts fill category, note, amount, and account', (
    tester,
  ) async {
    final accounts = [
      AccountBalance(account: _card, balance: 500),
      AccountBalance(account: _cash, balance: 1000),
    ];

    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.expense,
        accounts: accounts,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUICK ADD'), findsOneWidget);
    expect(find.textContaining('Cash'), findsNothing);

    await tester.tap(find.text('Rickshaw'));
    await tester.pumpAndSettle();

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('৳30'), findsOneWidget);
    expect(find.text('Rickshaw'), findsNWidgets(2));
    expect(find.textContaining('Cash'), findsOneWidget);
  });

  testWidgets(
    'Quick add shortcuts without a preset amount clear a typed value',
    (tester) async {
      await _pump(
        tester,
        TransactionEntrySheet(
          kind: TransactionEntryKind.expense,
          accounts: _accountBalances,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '999',
      );
      await tester.pumpAndSettle();
      expect(find.text('৳999'), findsOneWidget);

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(find.text('৳999'), findsNothing);
      expect(find.text('Lunch'), findsNWidgets(2));
    },
  );

  testWidgets(
    'Initial values from AI parsing pre-fill amount, category, and note',
    (tester) async {
      await _pump(
        tester,
        TransactionEntrySheet(
          kind: TransactionEntryKind.expense,
          accounts: _accountBalances,
          initialAmount: 500,
          initialCategory: 'Pizza Hut', // not in the default category list
          initialNote: 'Lunch at Pizza Hut',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('৳500'), findsOneWidget);
      expect(find.text('Pizza Hut'), findsOneWidget);
      expect(find.text('Lunch at Pizza Hut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Describe It dialog parses text and returns the parsed transaction',
    (tester) async {
      final aiService = AiService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'type': 'expense',
              'amount': 500,
              'category': 'Food',
              'note': 'Lunch at Pizza Hut',
            }),
            200,
          ),
        ),
        tokenProvider: () => 'fake-token',
      );
      ParsedTransactionEntry? result;

      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showNaturalLanguageTransactionDialog(
                  context: context,
                  aiService: aiService,
                );
              },
              child: const Text('Describe It'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Describe It'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nl-entry-text')),
        '500 on lunch at Pizza Hut',
      );
      await tester.tap(find.byKey(const ValueKey('nl-entry-parse')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isNotNull);
      expect(result!.kind, TransactionEntryKind.expense);
      expect(result!.amount, 500);
      expect(result!.category, 'Food');
      expect(result!.note, 'Lunch at Pizza Hut');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Describe It dialog shows a retryable error without crashing on failure',
    (tester) async {
      final aiService = AiService(
        client: MockClient(
          (request) async => http.Response('Service Unavailable', 503),
        ),
        tokenProvider: () => 'fake-token',
      );

      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showNaturalLanguageTransactionDialog(
                context: context,
                aiService: aiService,
              ),
              child: const Text('Describe It'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Describe It'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nl-entry-text')),
        'not enough info',
      );
      await tester.tap(find.byKey(const ValueKey('nl-entry-parse')));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't understand that"), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('renders Edit Transaction form fields', (tester) async {
    await _pump(
      tester,
      EditTransactionSheet(
        transaction: _expenseTransaction,
        accounts: _accountBalances,
        people: _people,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaction'), findsWidgets);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('Money In requires an amount before saving', (tester) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.income,
        accounts: _accountBalances,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Income'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });

  testWidgets('Transfer needs at least two accounts', (tester) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.transfer,
        accounts: _singleAccountBalance,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A transfer needs at least two accounts.'),
      findsOneWidget,
    );

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Transfer'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('Money In fits a narrow phone screen', (tester) async {
    await _pumpOnPhone(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.income,
        accounts: _longAccountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Income'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Add Income'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Transfer fits a narrow phone screen', (tester) async {
    await _pumpOnPhone(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.transfer,
        accounts: _longAccountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Transfer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Transaction fits a narrow phone screen', (tester) async {
    await _pumpOnPhone(
      tester,
      EditTransactionSheet(
        transaction: _expenseTransaction,
        accounts: _longAccountBalances,
        people: _people,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
}

Future<void> _pumpOnPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await _pump(tester, child);
}

final _now = DateTime(2026, 7, 7, 10, 30);

final _cash = Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: _now);

final _card = Account(id: 'card', name: 'Card', type: 'card', createdAt: _now);

final _accountBalances = [
  AccountBalance(account: _cash, balance: 1000),
  AccountBalance(account: _card, balance: 2500),
];

final _singleAccountBalance = [AccountBalance(account: _cash, balance: 1000)];

final _longAccountBalances = [
  AccountBalance(
    account: Account(
      id: 'long-cash',
      name: 'Primary household cash account with a very long name',
      type: 'cash',
      createdAt: _now,
    ),
    balance: 123456789,
  ),
  AccountBalance(
    account: Account(
      id: 'long-card',
      name: 'International credit card account with a very long name',
      type: 'card',
      createdAt: _now,
    ),
    balance: 987654321,
  ),
];

final _people = [Person(id: 'person-1', name: 'Sakib', createdAt: _now)];

final _expenseTransaction = TransactionRecord(
  id: 'tx-expense',
  type: 'expense',
  amount: 75,
  fromAccountId: 'cash',
  category: 'Food',
  note: 'Lunch',
  occurredAt: _now,
  createdAt: _now,
);
