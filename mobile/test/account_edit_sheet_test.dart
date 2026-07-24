import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/accounts/account_edit_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('Edit Account fits a narrow phone with large values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AccountEditSheet(accountBalance: _accountBalance),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Account'), findsWidgets);
    expect(find.text('Balance Adjustment'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).at(1), '987654321');
    await tester.pumpAndSettle();

    expect(find.text('New balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _accountBalance = AccountBalance(
  account: Account(
    id: 'account-1',
    name: 'Primary household account with a very long display name',
    type: 'cash',
    createdAt: DateTime(2026, 7, 10),
  ),
  balance: 123456789,
);
