import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/budget/budget_entry_sheet.dart';
import 'package:money_master/features/dashboard/dashboard_screen.dart';
import 'package:money_master/features/investments/investment_entry_sheets.dart';
import 'package:money_master/features/people/people_entry_sheets.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('submits income, expense, transfer, and transaction edits', (
    tester,
  ) async {
    _useDesktopTestSize(tester);
    final dataSource = _RecordingMoneyDataSource();

    for (final testCase in const [
      (TransactionEntryKind.income, 'Add Income', 'income'),
      (TransactionEntryKind.expense, 'Add Expense', 'expense'),
      (TransactionEntryKind.transfer, 'Transfer', 'transfer'),
    ]) {
      await _pump(
        tester,
        TransactionEntrySheet(
          kind: testCase.$1,
          accounts: _accountBalances,
          dataSource: dataSource,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Amount'), '123');
      await tester.tap(find.widgetWithText(FilledButton, testCase.$2));
      await tester.pumpAndSettle();
      expect(dataSource.calls, contains(testCase.$3));
      expect(dataSource.lastAmount, 123);
    }

    await _pump(
      tester,
      EditTransactionSheet(
        transaction: _expenseTransaction,
        accounts: _accountBalances,
        people: [_person],
        dataSource: dataSource,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_textField('Amount'), '88');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    expect(dataSource.calls, contains('update-transaction'));
    expect(dataSource.lastAmount, 88);
    expect(dataSource.lastId, _expenseTransaction.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits person create, edit, and all four loan actions', (
    tester,
  ) async {
    _useDesktopTestSize(tester);
    final dataSource = _RecordingMoneyDataSource();

    await _pump(tester, PersonEntrySheet(dataSource: dataSource));
    await tester.pumpAndSettle();
    await tester.enterText(_textField('Name'), 'Workflow Person');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Person'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('create-person'));
    expect(dataSource.lastName, 'Workflow Person');

    await _pump(
      tester,
      PersonEditSheet(person: _person, dataSource: dataSource),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_textField('Name'), 'Workflow Person Updated');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('update-person'));
    expect(dataSource.lastName, 'Workflow Person Updated');

    for (final action in LoanAction.values) {
      await _pump(
        tester,
        LoanEntrySheet(
          action: action,
          accounts: _accountBalances,
          people: [_person],
          dataSource: dataSource,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Amount'), '45');
      await tester.tap(find.widgetWithText(FilledButton, _loanTitle(action)));
      await tester.pumpAndSettle();
      expect(dataSource.calls, contains('loan-${action.name}'));
      expect(dataSource.lastAmount, 45);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('submits investment create, add funds, and return workflows', (
    tester,
  ) async {
    _useDesktopTestSize(tester);
    final dataSource = _RecordingMoneyDataSource();

    await _pump(
      tester,
      InvestmentEntrySheet(accounts: _accountBalances, dataSource: dataSource),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_textField('Investment name'), 'Workflow Fund');
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount')),
      '500',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Investment'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('create-investment'));
    expect(dataSource.lastName, 'Workflow Fund');
    expect(dataSource.lastAmount, 500);

    await _pump(
      tester,
      InvestmentFundsSheet(
        investment: _investment,
        accounts: _accountBalances,
        dataSource: dataSource,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount')),
      '75',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add Funds'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('add-investment-funds'));
    expect(dataSource.lastAmount, 75);

    await _pump(
      tester,
      InvestmentReturnSheet(
        investments: [_investment],
        accounts: _accountBalances,
        dataSource: dataSource,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('investment-amount')),
      '90',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Record Return'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('investment-return'));
    expect(dataSource.lastAmount, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves and clears a monthly budget', (tester) async {
    _useDesktopTestSize(tester);
    final dataSource = _RecordingMoneyDataSource();

    await _pump(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const ['Food'],
        existingBudgets: const {},
        transactions: const [],
        dataSource: dataSource,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budget-amount-Food')),
      '1200',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Budgets'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('save-budgets'));
    expect(dataSource.lastBudgets, {'Food': 1200});

    await _pump(
      tester,
      BudgetEntrySheet(
        month: DateTime(2026, 7),
        categories: const ['Food'],
        existingBudgets: const {'Food': 1200},
        transactions: const [],
        dataSource: dataSource,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-clear-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear Budgets'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('clear-budgets'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard deletion commands use the injected data source', (
    tester,
  ) async {
    _useDesktopTestSize(tester);
    final dataSource = _RecordingMoneyDataSource();

    await _pump(tester, DashboardScreen(user: _user, dataSource: dataSource));
    await tester.pumpAndSettle();
    final swipe = find.byKey(const ValueKey('transaction-swipe-income-1'));
    await _scrollDashboardTo(tester, swipe);
    await tester.fling(swipe, const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Transaction'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('delete-transaction'));
    expect(dataSource.lastId, 'income-1');

    await _pump(tester, DashboardScreen(user: _user, dataSource: dataSource));
    await tester.pumpAndSettle();
    await _openDashboardTab(tester, 'dashboard-tab-ledger');
    final personMenu = find.byTooltip('Person actions').first;
    await _scrollDashboardTo(tester, personMenu);
    await tester.tap(personMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Person'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('delete-person'));
    expect(dataSource.lastId, _person.id);

    await _pump(tester, DashboardScreen(user: _user, dataSource: dataSource));
    await tester.pumpAndSettle();
    await _openDashboardTab(tester, 'dashboard-tab-investments');
    final investmentMenu = find.byTooltip('Investment actions').first;
    await _scrollDashboardTo(tester, investmentMenu);
    await tester.tap(investmentMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Investment'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, contains('delete-investment'));
    expect(dataSource.lastId, _investment.id);
    expect(tester.takeException(), isNull);
  });
}

Finder _textField(String label) {
  return find.widgetWithText(TextFormField, label);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-workflow-screen'),
              onPressed: () {
                Navigator.of(
                  context,
                ).push<void>(MaterialPageRoute(builder: (context) => child));
              },
              child: const Text('Open workflow'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-workflow-screen')));
  await tester.pumpAndSettle();
}

void _useDesktopTestSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _dashboardScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('dashboard-scroll-view')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _scrollDashboardTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: _dashboardScrollable(),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDashboardTab(WidgetTester tester, String key) async {
  final tab = find.byKey(ValueKey(key));
  await _scrollDashboardTo(tester, tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

String _loanTitle(LoanAction action) {
  return switch (action) {
    LoanAction.borrow => 'Borrow Money',
    LoanAction.lend => 'Give Loan',
    LoanAction.repay => 'Repay Loan',
    LoanAction.receive => 'Receive Repayment',
  };
}

class _RecordingMoneyDataSource implements MoneyDataSource {
  final calls = <String>[];
  double? lastAmount;
  String? lastId;
  String? lastName;
  Map<String, double>? lastBudgets;

  @override
  Future<DashboardSnapshot> fetchDashboard() async => _snapshot;

  @override
  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    calls.add('income');
    lastAmount = amount;
  }

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    calls.add('expense');
    lastAmount = amount;
  }

  @override
  Future<void> createTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    calls.add('transfer');
    lastAmount = amount;
  }

  @override
  Future<void> createPerson({
    required String name,
    String? phone,
    String? note,
  }) async {
    calls.add('create-person');
    lastName = name;
  }

  @override
  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
  }) async {
    calls.add('update-person');
    lastId = personId;
    lastName = name;
  }

  @override
  Future<void> deletePerson(String personId) async {
    calls.add('delete-person');
    lastId = personId;
  }

  @override
  Future<void> updateAccount({
    required String accountId,
    required String name,
    required double adjustmentAmount,
    required bool addMoney,
    String? note,
  }) async {
    calls.add('update-account');
    lastId = accountId;
    lastName = name;
    lastAmount = adjustmentAmount;
  }

  @override
  Future<void> createLoanTransaction({
    required String type,
    required double amount,
    required String accountId,
    required String personId,
    required DateTime occurredAt,
    String? note,
  }) async {
    calls.add('loan-$type');
    lastAmount = amount;
    lastId = personId;
  }

  @override
  Future<void> createInvestment({
    required String name,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? description,
    String? note,
  }) async {
    calls.add('create-investment');
    lastName = name;
    lastAmount = amount;
  }

  @override
  Future<void> addInvestmentFunds({
    required String investmentId,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    calls.add('add-investment-funds');
    lastId = investmentId;
    lastAmount = amount;
  }

  @override
  Future<void> recordInvestmentReturn({
    required String investmentId,
    required double amount,
    required String toAccountId,
    required DateTime occurredAt,
    required bool closeInvestment,
    String? note,
  }) async {
    calls.add('investment-return');
    lastId = investmentId;
    lastAmount = amount;
  }

  @override
  Future<void> updateTransaction({
    required TransactionRecord transaction,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? toAccountId,
    String? personId,
    String? category,
    String? note,
  }) async {
    calls.add('update-transaction');
    lastId = transaction.id;
    lastAmount = amount;
  }

  @override
  Future<void> replaceBudgetsForMonth({
    required DateTime month,
    required Map<String, double> budgets,
  }) async {
    calls.add('save-budgets');
    lastBudgets = Map<String, double>.from(budgets);
  }

  @override
  Future<void> clearBudgetsForMonth(DateTime month) async {
    calls.add('clear-budgets');
  }

  @override
  Future<void> deleteInvestment(String investmentId) async {
    calls.add('delete-investment');
    lastId = investmentId;
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    calls.add('delete-transaction');
    lastId = transactionId;
  }
}

final _now = DateTime.now();

const _user = User(
  id: 'workflow-user',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'workflow@example.com',
  createdAt: '2026-07-10T00:00:00.000Z',
);

final _cash = Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: _now);

final _wallet = Account(
  id: 'wallet',
  name: 'Wallet',
  type: 'wallet',
  createdAt: _now,
);

final _accountBalances = [
  AccountBalance(account: _cash, balance: 1000),
  AccountBalance(account: _wallet, balance: 500),
];

final _person = Person(id: 'person-1', name: 'Alex', createdAt: _now);

final _investment = Investment(
  id: 'investment-1',
  name: 'Workflow Investment',
  status: 'active',
  createdAt: _now,
);

final _expenseTransaction = TransactionRecord(
  id: 'expense-1',
  type: 'expense',
  amount: 75,
  fromAccountId: _cash.id,
  category: 'Food',
  occurredAt: _now,
  createdAt: _now,
);

final _snapshot = DashboardSnapshot(
  accounts: [_cash, _wallet],
  people: [_person],
  investments: [_investment],
  budgets: const [],
  transactions: [
    TransactionRecord(
      id: 'income-1',
      type: 'income',
      amount: 1000,
      toAccountId: _cash.id,
      category: 'Salary',
      occurredAt: _now,
      createdAt: _now,
    ),
    TransactionRecord(
      id: 'lend-1',
      type: 'lend',
      amount: 100,
      fromAccountId: _cash.id,
      personId: _person.id,
      category: 'Loan Given',
      occurredAt: _now,
      createdAt: _now,
    ),
    TransactionRecord(
      id: 'invest-1',
      type: 'invest',
      amount: 200,
      fromAccountId: _wallet.id,
      investmentId: _investment.id,
      category: 'Investment',
      occurredAt: _now,
      createdAt: _now,
    ),
  ],
);
