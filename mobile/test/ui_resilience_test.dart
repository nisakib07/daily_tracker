import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/accounts/account_edit_sheet.dart';
import 'package:money_master/features/auth/sign_in_screen.dart';
import 'package:money_master/features/budget/budget_entry_sheet.dart';
import 'package:money_master/features/investments/investment_entry_sheets.dart';
import 'package:money_master/features/people/people_entry_sheets.dart';
import 'package:money_master/features/settings/settings_sheet.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final fixedActionForms =
      <({String name, Widget Function() build, String action})>[
        (
          name: 'Money In',
          build: () => TransactionEntrySheet(
            kind: TransactionEntryKind.income,
            accounts: _accounts,
          ),
          action: 'Add Income',
        ),
        (
          name: 'Account Edit',
          build: () => AccountEditSheet(accountBalance: _accounts.first),
          action: 'Save Changes',
        ),
        (
          name: 'Add Person',
          build: () => const PersonEntrySheet(),
          action: 'Add Person',
        ),
        (
          name: 'Borrow Money',
          build: () => LoanEntrySheet(
            action: LoanAction.borrow,
            accounts: _accounts,
            people: [_person],
          ),
          action: 'Borrow Money',
        ),
        (
          name: 'Budget',
          build: () => BudgetEntrySheet(
            month: DateTime(2026, 7),
            categories: const [_veryLongCategory],
            existingBudgets: const {'Food': 123456789},
          ),
          action: 'Save Budgets',
        ),
        (
          name: 'New Investment',
          build: () => InvestmentEntrySheet(accounts: _accounts),
          action: 'Create Investment',
        ),
      ];

  for (final form in fixedActionForms) {
    testWidgets('${form.name} keeps its action visible above the keyboard', (
      tester,
    ) async {
      await _pumpWithKeyboard(tester, form.build());
      await tester.pumpAndSettle();

      final action = find.widgetWithText(FilledButton, form.action);
      expect(action, findsOneWidget);
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Settings focused input stays usable above the keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dmt_custom_income_categories': <String>[_veryLongCategory],
    });
    await _pumpWithKeyboard(
      tester,
      const SettingsSheet(email: 'long.account.email@example-company.com'),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('settings-income-input'));
    await tester.scrollUntilVisible(
      input,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(input, 'Consulting');
    await tester.pumpAndSettle();

    expect(input.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-income-add')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign In scrolls focused fields above the keyboard', (
    tester,
  ) async {
    await _pumpWithKeyboard(tester, const SignInScreen());
    await tester.pumpAndSettle();

    final password = find.widgetWithText(TextFormField, 'Password');
    await tester.tap(password);
    await tester.pumpAndSettle();

    expect(password.hitTestable(), findsOneWidget);

    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.scrollUntilVisible(
      signIn,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('sign-in-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(signIn.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWithKeyboard(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = const FakeViewPadding(bottom: 260);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}

const _veryLongCategory =
    'A category with an exceptionally long name for overflow resilience testing';

final _now = DateTime(2026, 7, 10);

final _person = Person(
  id: 'person-1',
  name: 'A person with an exceptionally long display name',
  createdAt: _now,
);

final _accounts = [
  AccountBalance(
    account: Account(
      id: 'account-1',
      name: 'Primary household account with an exceptionally long display name',
      type: 'cash',
      createdAt: _now,
    ),
    balance: 987654321,
  ),
  AccountBalance(
    account: Account(
      id: 'account-2',
      name: 'Secondary account with another exceptionally long display name',
      type: 'card',
      createdAt: _now,
    ),
    balance: 123456789,
  ),
];
