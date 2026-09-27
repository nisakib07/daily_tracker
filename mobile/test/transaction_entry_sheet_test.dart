import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _quickAddKey = 'dmt_quick_add_shortcuts';

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

  testWidgets('Quick add section is hidden when no shortcuts are saved', (
    tester,
  ) async {
    await _pump(
      tester,
      TransactionEntrySheet(
        kind: TransactionEntryKind.expense,
        accounts: _accountBalances,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUICK ADD'), findsNothing);
  });

  testWidgets('Quick add shortcuts fill category, note, amount, and account', (
    tester,
  ) async {
    final accounts = [
      AccountBalance(account: _card, balance: 500),
      AccountBalance(account: _cash, balance: 1000),
    ];

    SharedPreferences.setMockInitialValues({
      _quickAddKey: jsonEncode([
        {
          'id': 'qa-rickshaw',
          'category': 'Transport',
          'subCategory': 'Rickshaw',
          'accountId': _cash.id,
          'amount': 30,
        },
      ]),
    });

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
      SharedPreferences.setMockInitialValues({
        _quickAddKey: jsonEncode([
          {
            'id': 'qa-lunch',
            'category': 'Food',
            'subCategory': 'Lunch',
            'accountId': _cash.id,
          },
        ]),
      });

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

    expect(find.text('Enter an amount'), findsOneWidget);
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
