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

  testWidgets('repay shows what you owe and warns when paying more', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      LoanEntrySheet(
        action: LoanAction.repay,
        accounts: _accounts,
        people: [_rahim],
        transactions: [_rahimLoan('borrow', 1000)],
      ),
    );
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextFormField, 'Amount');

    expect(find.text('You owe Rahim ৳1,000'), findsOneWidget);

    await tester.enterText(amount, '800');
    await tester.pump();
    expect(find.textContaining('more than is owed'), findsNothing);

    await tester.enterText(amount, '1500');
    await tester.pump();
    expect(
      find.text(
        'This is ৳500 more than is owed. The extra will show as Rahim '
        'owing you.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('receiving when nothing is owed says where it will show', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      LoanEntrySheet(
        action: LoanAction.receive,
        accounts: _accounts,
        people: [_rahim],
        transactions: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Rahim doesn't owe you anything"), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.pump();
    expect(
      find.text(
        'Nothing is owed right now, so this will show as you owing Rahim '
        '৳100.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lending shows no repayment hint', (tester) async {
    await _pumpOnPhone(
      tester,
      LoanEntrySheet(
        action: LoanAction.lend,
        accounts: _accounts,
        people: [_rahim],
        transactions: [_rahimLoan('borrow', 1000)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('You owe'), findsNothing);
  });

  testWidgets('history shows an overpaid loan the other way round', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      PersonHistorySheet(
        person: _rahim,
        transactions: [_rahimLoan('borrow', 1000), _rahimLoan('repay', 1500)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('They owe you'), findsWidgets);
    expect(find.text('৳500'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final _rahim = Person(id: 'rahim', name: 'Rahim', createdAt: _now);

var _loanSequence = 0;

TransactionRecord _rahimLoan(String type, double amount) {
  return TransactionRecord(
    id: 'rahim-loan-${_loanSequence++}',
    type: type,
    amount: amount,
    personId: _rahim.id,
    occurredAt: _now,
    createdAt: _now,
  );
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
