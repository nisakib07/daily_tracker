import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/analytics/analytics_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('Analytics report fits and scrolls on a narrow phone', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      AnalyticsSheet(snapshot: _snapshot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Financial overview'), findsOneWidget);
    expect(find.text('Financial Health'), findsOneWidget);
    expect(find.text('Monthly Flow'), findsOneWidget);
    expect(find.text('Cash Flow Forecast'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('analytics-scroll-view')),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spending Heatmap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Analytics uses paired modules in a wide desktop workspace', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(1440, 900),
      AnalyticsSheet(snapshot: _snapshot),
    );
    await tester.pumpAndSettle();

    final workspaceSize = tester.getSize(
      find.byKey(const ValueKey('analytics-workspace')),
    );
    final healthTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('analytics-health-card')),
    );
    final flowTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('analytics-flow-card')),
    );
    final categoryTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('analytics-category-card')),
    );
    final heatmapTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('analytics-heatmap-card')),
    );

    expect(workspaceSize.width, lessThanOrEqualTo(960));
    expect(flowTopLeft.dx, greaterThan(healthTopLeft.dx));
    expect(flowTopLeft.dy, closeTo(healthTopLeft.dy, 1));
    expect(heatmapTopLeft.dx, greaterThan(categoryTopLeft.dx));
    expect(heatmapTopLeft.dy, closeTo(categoryTopLeft.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Financial health flags a brand-new account instead of guessing a grade',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 568),
        const AnalyticsSheet(snapshot: _emptySnapshot),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Add a few weeks of transactions to unlock a meaningful score.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Financial health computes a real financial cushion score from balance and history',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 568),
        AnalyticsSheet(snapshot: _healthySnapshot),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financial Cushion'), findsOneWidget);
      expect(find.textContaining('Excellent'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cash flow forecast projects a decline from real history', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      AnalyticsSheet(snapshot: _decliningSnapshot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash Flow Forecast'), findsOneWidget);
    expect(find.textContaining('you will run low by'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Analytics has useful empty states', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      const AnalyticsSheet(snapshot: _emptySnapshot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start tracking this month'), findsOneWidget);
    expect(find.text('No expenses this month.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping a heatmap day shows that day\'s expenses', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      AnalyticsSheet(snapshot: _snapshot),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('analytics-scroll-view')),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();

    final todayKey = ValueKey(
      'heatmap-cell-${DateFormat('yyyy-MM-dd').format(_now)}',
    );
    await tester.tap(find.byKey(todayKey));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('day-detail-sheet'));
    expect(
      find.descendant(of: sheet, matching: find.text('2 expenses')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Household groceries and daily essentials'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Utilities and recurring bills'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping an empty heatmap day shows an empty state', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      AnalyticsSheet(snapshot: _snapshot),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('analytics-scroll-view')),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();

    final firstOfMonth = DateTime(_now.year, _now.month, 1);
    final emptyKey = ValueKey(
      'heatmap-cell-${DateFormat('yyyy-MM-dd').format(firstOfMonth)}',
    );
    if (firstOfMonth.day == _now.day &&
        firstOfMonth.month == _now.month &&
        firstOfMonth.year == _now.year) {
      return;
    }

    await tester.tap(find.byKey(emptyKey));
    await tester.pumpAndSettle();

    expect(find.text('Nothing spent this day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Analytics helper opens and closes a full-page route', (
    tester,
  ) async {
    var analyticsClosed = false;
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                await showAnalyticsSheet(context: context, snapshot: _snapshot);
                analyticsClosed = true;
              },
              child: const Text('Open analytics'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Financial overview'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(analyticsClosed, isTrue);
    expect(find.text('Open analytics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
}

final _now = DateTime.now();
final _lastMonth = DateTime(_now.year, _now.month - 1, 12);

final _account = Account(
  id: 'account-1',
  name: 'Primary household account with a very long display name',
  type: 'cash',
  createdAt: _now,
);

final _snapshot = DashboardSnapshot(
  accounts: [_account],
  people: const [],
  investments: const [],
  budgets: [
    Budget(
      id: 'budget-1',
      month: DateTime(_now.year, _now.month),
      category: 'Household groceries and daily essentials',
      amount: 50000,
      createdAt: _now,
      updatedAt: _now,
    ),
  ],
  transactions: [
    _transaction(
      id: 'income-current',
      type: 'income',
      amount: 125000,
      occurredAt: _now,
      toAccountId: _account.id,
      category: 'Monthly salary',
    ),
    _transaction(
      id: 'expense-current-1',
      type: 'expense',
      amount: 35000,
      occurredAt: _now,
      fromAccountId: _account.id,
      category: 'Household groceries and daily essentials',
    ),
    _transaction(
      id: 'expense-current-2',
      type: 'expense',
      amount: 12000,
      occurredAt: _now,
      fromAccountId: _account.id,
      category: 'Utilities and recurring bills',
    ),
    _transaction(
      id: 'expense-last-month',
      type: 'expense',
      amount: 40000,
      occurredAt: _lastMonth,
      fromAccountId: _account.id,
      category: 'Household groceries and daily essentials',
    ),
  ],
);

// 20 days of a small net outflow (-80/day) inside the 30-day forecast
// window, plus one anchor income outside the window that funds the
// starting balance without affecting the trailing daily-flow average.
// Net: avgDailyNetChange ~= -1600/30, balance 3400 -> ~63 days of runway,
// landing in the "declining" (not yet critical) branch deterministically.
final _decliningTransactions = [
  _transaction(
    id: 'anchor-balance',
    type: 'income',
    amount: 5000,
    occurredAt: _now.subtract(const Duration(days: 35)),
    toAccountId: _account.id,
    category: 'Opening balance',
  ),
  for (var i = 1; i <= 20; i++)
    _transaction(
      id: 'decline-expense-$i',
      type: 'expense',
      amount: 100,
      occurredAt: _now.subtract(Duration(days: i)),
      fromAccountId: _account.id,
      category: 'Daily spend',
    ),
  for (var i = 1; i <= 20; i++)
    _transaction(
      id: 'decline-income-$i',
      type: 'income',
      amount: 20,
      occurredAt: _now.subtract(Duration(days: i)),
      toAccountId: _account.id,
      category: 'Side income',
    ),
];

final _decliningSnapshot = DashboardSnapshot(
  accounts: [_account],
  people: const [],
  investments: const [],
  budgets: const [],
  transactions: _decliningTransactions,
);

// 45 days of steady income (200/day) and expense (100/day) covering both
// the trailing 30-day window and enough of the 30-60-day prior window for
// consistency/income-stability to have real data, plus an old anchor
// income outside both windows so the resulting balance gives a long
// (>90 day) financial cushion runway - i.e. an "Excellent" cushion score.
final _healthyTransactions = [
  _transaction(
    id: 'healthy-anchor',
    type: 'income',
    amount: 20000,
    occurredAt: _now.subtract(const Duration(days: 70)),
    toAccountId: _account.id,
    category: 'Opening balance',
  ),
  for (var i = 1; i <= 45; i++)
    _transaction(
      id: 'healthy-income-$i',
      type: 'income',
      amount: 200,
      occurredAt: _now.subtract(Duration(days: i)),
      toAccountId: _account.id,
      category: 'Salary',
    ),
  for (var i = 1; i <= 45; i++)
    _transaction(
      id: 'healthy-expense-$i',
      type: 'expense',
      amount: 100,
      occurredAt: _now.subtract(Duration(days: i)),
      fromAccountId: _account.id,
      category: 'Living costs',
    ),
];

final _healthySnapshot = DashboardSnapshot(
  accounts: [_account],
  people: const [],
  investments: const [],
  budgets: const [],
  transactions: _healthyTransactions,
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
  required DateTime occurredAt,
  String? fromAccountId,
  String? toAccountId,
  String? category,
}) {
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    category: category,
    occurredAt: occurredAt,
    createdAt: occurredAt,
  );
}
