import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/investments/investment_entry_sheets.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('New Investment fits a narrow phone and validates locally', (
    tester,
  ) async {
    await _pumpOnPhone(tester, InvestmentEntrySheet(accounts: _accounts));
    await tester.pumpAndSettle();

    expect(find.text('New Investment'), findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Investment name'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create Investment'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Investment'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Funds fits a narrow phone with long names', (tester) async {
    await _pumpOnPhone(
      tester,
      InvestmentFundsSheet(investment: _investment, accounts: _accounts),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Funds'), findsWidgets);
    expect(find.text('Adding to'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add Funds'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('investment-form-scroll-Add Funds')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Add Funds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Record Return recovers from a stale selected investment', (
    tester,
  ) async {
    await _pumpOnPhone(
      tester,
      InvestmentReturnSheet(
        investments: [_investment],
        accounts: _accounts,
        selectedInvestment: _staleInvestment,
      ),
    );
    await tester.pumpAndSettle();

    final investmentDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    expect(investmentDropdown.initialValue, _investment.id);
    expect(find.text('Record Return'), findsWidgets);

    await tester.drag(
      find.byKey(const ValueKey('investment-form-scroll-Record Return')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.text('Close after return'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Record Return'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Investment forms disable saving when required data is missing', (
    tester,
  ) async {
    await _pumpOnPhone(tester, const InvestmentEntrySheet(accounts: []));
    await tester.pumpAndSettle();

    expect(
      find.text('No accounts found. Add or restore accounts before investing.'),
      findsOneWidget,
    );
    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create Investment'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);

    await _pumpOnPhone(
      tester,
      const InvestmentReturnSheet(investments: [], accounts: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active investments found.'), findsOneWidget);
    expect(
      find.text('No accounts found. Add or restore accounts before investing.'),
      findsOneWidget,
    );
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Record Return'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Investment helper opens a full-page route', (tester) async {
    bool? result;
    await _pumpOnPhone(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showInvestmentEntrySheet(
                  context: context,
                  accounts: _accounts,
                );
              },
              child: const Text('Open investment'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open investment'));
    await tester.pumpAndSettle();
    expect(find.text('Track a business, asset, or fund'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Open investment'), findsOneWidget);
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

final _now = DateTime(2026, 7, 10);

final _investment = Investment(
  id: 'investment-1',
  name: 'A diversified family investment with an exceptionally long name',
  description: 'Long-term investment used for responsive layout coverage.',
  status: 'active',
  createdAt: _now,
);

final _staleInvestment = Investment(
  id: 'investment-no-longer-available',
  name: 'Old investment',
  status: 'active',
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
