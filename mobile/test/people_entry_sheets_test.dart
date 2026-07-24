import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/people/people_entry_sheets.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('Add Person fits a narrow phone', (tester) async {
    await _pumpOnPhone(tester, const PersonEntrySheet());
    await tester.pumpAndSettle();

    expect(find.text('Add Person'), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add Person'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Person fits a narrow phone with long details', (
    tester,
  ) async {
    await _pumpOnPhone(tester, PersonEditSheet(person: _person));
    await tester.pumpAndSettle();

    expect(find.text('Edit Person'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final action in LoanAction.values) {
    testWidgets('${action.name} form fits a narrow phone', (tester) async {
      await _pumpOnPhone(
        tester,
        LoanEntrySheet(
          action: action,
          accounts: _accounts,
          people: [_person],
          initialPersonId: 'person-that-no-longer-exists',
        ),
      );
      await tester.pumpAndSettle();

      final title = _loanTitle(action);
      expect(find.text(title), findsWidgets);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Person'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpOnPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
}

String _loanTitle(LoanAction action) {
  return switch (action) {
    LoanAction.borrow => 'Borrow Money',
    LoanAction.lend => 'Give Loan',
    LoanAction.repay => 'Repay Loan',
    LoanAction.receive => 'Receive Repayment',
  };
}

final _now = DateTime(2026, 7, 10);

final _person = Person(
  id: 'person-1',
  name: 'A person with an exceptionally long display name',
  phone: '+880 1700 000000',
  note: 'A long note used to verify that contact details stay responsive.',
  createdAt: _now,
);

final _accounts = [
  AccountBalance(
    account: Account(
      id: 'account-1',
      name: 'Primary household account with a very long display name',
      type: 'cash',
      createdAt: _now,
    ),
    balance: 123456789,
  ),
];
