import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/app_update_checker.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/dashboard/dashboard_screen.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('deleting a person who still owes you warns with the amount', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      const Size(900, 1400),
      snapshotLoader: () async => _snapshot,
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'dashboard-tab-ledger');

    final actions = find.byTooltip('Person actions').first;
    await _scrollTo(tester, actions);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('${_person.name} still owes you ৳12,000.'),
      findsOneWidget,
    );
    expect(find.textContaining('record the repayment instead'), findsOneWidget);
    expect(find.text('Delete anyway'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete anyway'), findsNothing);
  });

  testWidgets('deleting a settled person keeps the plain confirmation', (
    tester,
  ) async {
    final settled = DashboardSnapshot(
      accounts: _snapshot.accounts,
      people: [_person],
      investments: const [],
      transactions: const [],
      budgets: const [],
    );
    await _pumpDashboard(
      tester,
      const Size(900, 1400),
      snapshotLoader: () async => settled,
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'dashboard-tab-ledger');

    final actions = find.byTooltip('Person actions').first;
    await _scrollTo(tester, actions);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('still owes'), findsNothing);
    expect(find.text('Delete Person'), findsOneWidget);
  });

  testWidgets('the update banner is above the list and takes taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(
          user: _user,
          snapshotLoader: () async => _snapshot,
          updateChecker: () async => const AppUpdateInfo(
            buildNumber: 25,
            downloadUrl: 'https://example.com/app-release.apk',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The banner used to be drawn under the full-screen dashboard list,
    // which covered it and took every tap meant for its buttons.
    final update = find.widgetWithText(TextButton, 'Update');
    final hit = tester.hitTestOnBinding(tester.getCenter(update));
    expect(
      hit.path.any((entry) => entry.target == tester.renderObject(update)),
      isTrue,
    );

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('dashboard fits a narrow phone across every tab', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DashboardScreen(
          user: _user,
          snapshotLoader: () async => _snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Money Master'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final activityModes = find.byKey(const ValueKey('activity-mode-switcher'));
    await tester.scrollUntilVisible(
      activityModes,
      300,
      scrollable: _dashboardScrollable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: activityModes, matching: find.text('All')),
      findsNothing,
    );
    await _scrollTo(tester, find.byType(Dismissible).first);
    final transactionSwipe = tester.widget<Dismissible>(
      find.byType(Dismissible).first,
    );
    expect(transactionSwipe.direction, DismissDirection.horizontal);
    expect(tester.takeException(), isNull);
    await tester.fling(
      find.byKey(const ValueKey('dashboard-scroll-view')),
      const Offset(0, 2000),
      1000,
    );
    await tester.pumpAndSettle();

    await _openTab(tester, 'dashboard-tab-ledger');
    await _scrollTo(tester, find.text('Open Balances'));
    expect(find.text('Open Balances'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'dashboard-tab-budget');
    await _scrollTo(tester, find.text('Set Budgets'));
    expect(find.text('Set Budgets'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'dashboard-tab-investments');
    await _scrollTo(tester, find.text('Investment Portfolio'));
    expect(find.text('Investment Portfolio'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.fling(find.byType(ListView), const Offset(0, -900), 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('amounts with paisa fit a narrow phone across every tab', (
    tester,
  ) async {
    // Amounts used to be rounded to whole Taka; with paisa shown, figures
    // like ৳500,000.37 are longer and must still fit.
    final withPaisa = DashboardSnapshot(
      accounts: _snapshot.accounts,
      people: _snapshot.people,
      investments: _snapshot.investments,
      budgets: _snapshot.budgets,
      transactions: [
        for (final item in _snapshot.transactions)
          TransactionRecord(
            id: item.id,
            type: item.type,
            amount: item.amount + 0.37,
            fromAccountId: item.fromAccountId,
            toAccountId: item.toAccountId,
            personId: item.personId,
            investmentId: item.investmentId,
            category: item.category,
            note: item.note,
            occurredAt: item.occurredAt,
            createdAt: item.createdAt,
          ),
      ],
    );
    await _pumpDashboard(
      tester,
      const Size(320, 568),
      snapshotLoader: () async => withPaisa,
    );
    await tester.pumpAndSettle();
    // Some amount on screen shows paisa (balances sum several of them).
    expect(find.textContaining(RegExp(r'৳-?[\d,]+\.\d\d')), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final tab in const [
      'dashboard-tab-ledger',
      'dashboard-tab-budget',
      'dashboard-tab-investments',
      'dashboard-tab-activity',
    ]) {
      await _openTab(tester, tab);
      await tester.fling(
        find.byKey(const ValueKey('dashboard-scroll-view')),
        const Offset(0, -1500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('dashboard stays centered and compact on wide desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DashboardScreen(
          user: _user,
          snapshotLoader: () async => _snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dashboardContent = find.byKey(const ValueKey('dashboard-content'));
    final topBarContent = find.byKey(
      const ValueKey('dashboard-topbar-content'),
    );
    final accountCard = find.byKey(const ValueKey('account-card-cash'));

    expect(tester.getSize(dashboardContent).width, 1120);
    expect(tester.getTopLeft(dashboardContent).dx, 160);
    expect(tester.getSize(topBarContent).width, 1120);
    expect(tester.getSize(accountCard).height, 154);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows a structured loading skeleton', (tester) async {
    final completer = Completer<DashboardSnapshot>();
    await _pumpDashboard(
      tester,
      const Size(320, 568),
      snapshotLoader: () => completer.future,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('dashboard-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    completer.complete(_emptySnapshot);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard sanitizes load errors and retry recovers', (
    tester,
  ) async {
    var attempts = 0;
    await _pumpDashboard(
      tester,
      const Size(320, 568),
      snapshotLoader: () async {
        attempts++;
        if (attempts == 1) {
          throw Exception('private backend details must stay hidden');
        }
        return _emptySnapshot;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load dashboard'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Try Again'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Try Again'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dashboard-loading-skeleton')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('dashboard-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty dashboard has clear states across every workspace', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      const Size(320, 568),
      snapshotLoader: () async => _emptySnapshot,
    );
    await tester.pumpAndSettle();

    expect(find.text('No accounts found'), findsOneWidget);
    await _scrollTo(tester, find.text('No activity found'));
    expect(find.text('No activity found'), findsOneWidget);

    await _openTab(tester, 'dashboard-tab-ledger');
    await _scrollTo(tester, find.text('No people yet'));
    expect(find.text('No people yet'), findsOneWidget);

    await _openTab(tester, 'dashboard-tab-budget');
    await _scrollTo(tester, find.text('No budgets yet'));
    expect(find.text('No budgets yet'), findsOneWidget);

    await _openTab(tester, 'dashboard-tab-investments');
    await _scrollTo(tester, find.text('No investments yet'));
    expect(find.text('No investments yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard remains stable at 280 pixels wide', (tester) async {
    await _pumpDashboard(
      tester,
      const Size(280, 568),
      snapshotLoader: () async => _snapshot,
    );
    await tester.pumpAndSettle();

    expect(find.text('Money Master'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final tab in const [
      'dashboard-tab-ledger',
      'dashboard-tab-budget',
      'dashboard-tab-investments',
      'dashboard-tab-activity',
    ]) {
      await _openTab(tester, tab);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Activity renders history in batches', (tester) async {
    final busySnapshot = DashboardSnapshot(
      accounts: [_cash],
      people: const [],
      investments: const [],
      budgets: const [],
      transactions: List.generate(
        150,
        (index) => _transaction(
          id: 'paged-activity-$index',
          type: 'income',
          amount: index + 1,
          toAccountId: _cash.id,
          category: 'Paged history',
        ),
      ),
    );
    await _pumpDashboard(
      tester,
      const Size(1440, 900),
      snapshotLoader: () async => busySnapshot,
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Load 50 older'));
    expect(find.text('Load 50 older'), findsOneWidget);
    await tester.tap(find.text('Load 50 older'));
    await tester.pumpAndSettle();

    expect(find.text('Load 50 older'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard commands expose accessible labels and actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpDashboard(
      tester,
      const Size(1440, 900),
      snapshotLoader: () async => _snapshot,
    );
    await tester.pumpAndSettle();

    final account = find.bySemanticsLabel(
      'Edit account Primary household cash account',
    );
    expect(account, findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Edit account').first).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('Previous month').first).height,
      greaterThanOrEqualTo(48),
    );

    final transaction = find.bySemanticsLabel(
      RegExp('Monthly salary with a long category name'),
    );
    await _scrollTo(tester, transaction);
    final data = tester.getSemantics(transaction).getSemanticsData();
    final customLabels = (data.customSemanticsActionIds ?? const <int>[])
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .map((action) => action.label)
        .toSet();

    expect(customLabels, contains('Edit transaction'));
    expect(customLabels, contains('Delete transaction'));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick actions sheet opens under the dark theme without error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(
          user: _user,
          snapshotLoader: () async => _snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Quick actions'));
    await tester.pumpAndSettle();

    expect(find.text('Money In'), findsOneWidget);
    expect(find.text('Money Out'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('New Investment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  Size size, {
  required Future<DashboardSnapshot> Function() snapshotLoader,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: DashboardScreen(user: _user, snapshotLoader: snapshotLoader),
    ),
  );
}

Future<void> _openTab(WidgetTester tester, String key) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    final label = switch (key) {
      'dashboard-tab-activity' => 'Activity',
      'dashboard-tab-ledger' => 'Ledger',
      'dashboard-tab-budget' => 'Budget',
      'dashboard-tab-investments' => 'Invest',
      _ => throw ArgumentError.value(key, 'key'),
    };
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.selectedIndex,
      ['Activity', 'Ledger', 'Budget', 'Invest'].indexOf(label),
    );
    return;
  }

  final tab = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(tab, 300, scrollable: _dashboardScrollable());
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Finder _dashboardScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('dashboard-scroll-view')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: _dashboardScrollable(),
  );
  await tester.pumpAndSettle();
}

final _now = DateTime.now();

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'a-very-long-email-address@example.com',
  createdAt: '2026-07-10T00:00:00.000Z',
);

final _cash = Account(
  id: 'cash',
  name: 'Primary household cash account',
  type: 'cash',
  createdAt: _now,
);

final _wallet = Account(
  id: 'wallet',
  name: 'Mobile wallet with a long name',
  type: 'wallet',
  createdAt: _now,
);

final _card = Account(
  id: 'card',
  name: 'International credit card',
  type: 'card',
  createdAt: _now,
);

final _person = Person(
  id: 'person-1',
  name: 'A person with a long display name',
  createdAt: _now,
);

final _investment = Investment(
  id: 'investment-1',
  name: 'Long-term diversified investment fund',
  description: 'A deliberately long investment description for layout tests.',
  status: 'active',
  createdAt: _now,
);

final _snapshot = DashboardSnapshot(
  accounts: [_cash, _wallet, _card],
  people: [_person],
  investments: [_investment],
  budgets: [
    Budget(
      id: 'budget-1',
      month: DateTime(_now.year, _now.month),
      category: 'Household groceries and daily essentials',
      amount: 25000,
      createdAt: _now,
      updatedAt: _now,
    ),
  ],
  transactions: [
    _transaction(
      id: 'income-1',
      type: 'income',
      amount: 123456789,
      toAccountId: _cash.id,
      category: 'Monthly salary with a long category name',
    ),
    _transaction(
      id: 'expense-1',
      type: 'expense',
      amount: 98765,
      fromAccountId: _cash.id,
      category: 'Household groceries and daily essentials',
    ),
    _transaction(
      id: 'transfer-1',
      type: 'transfer',
      amount: 50000,
      fromAccountId: _cash.id,
      toAccountId: _wallet.id,
    ),
    _transaction(
      id: 'lend-1',
      type: 'lend',
      amount: 12000,
      fromAccountId: _wallet.id,
      personId: _person.id,
    ),
    _transaction(
      id: 'invest-1',
      type: 'invest',
      amount: 500000,
      fromAccountId: _card.id,
      investmentId: _investment.id,
    ),
    _transaction(
      id: 'return-1',
      type: 'invest_return',
      amount: 550000,
      toAccountId: _card.id,
      investmentId: _investment.id,
    ),
  ],
);

const _emptySnapshot = DashboardSnapshot(
  accounts: [],
  people: [],
  investments: [],
  transactions: [],
  budgets: [],
);

TransactionRecord _transaction({
  required String id,
  required String type,
  required double amount,
  String? fromAccountId,
  String? toAccountId,
  String? personId,
  String? investmentId,
  String? category,
}) {
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    personId: personId,
    investmentId: investmentId,
    category: category,
    note: 'A long transaction note used to verify compact dashboard rows.',
    occurredAt: _now,
    createdAt: _now,
  );
}
