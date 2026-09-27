import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/date_times.dart';
import 'package:money_master/data/cached_money_data_source.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/features/dashboard/dashboard_screen.dart';
import 'package:money_master/features/sync/unsynced_changes_screen.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _deletedReference = PostgrestException(
  message: 'insert or update violates foreign key constraint',
  code: '23503',
);

void main() {
  test('describes changes with names from the snapshot', () {
    final queue = _queue();
    final expense = queue.create('money_out', {
      'amount': 250,
      'account_id': 'cash',
      'category': 'Food',
      'occurred_at': toSupabaseTimestamp(DateTime(2026, 9, 12, 10)),
    });
    final loan = queue.create('loan', {
      'type': 'lend',
      'amount': 1000,
      'account_id': 'bkash',
      'person_id': 'rahim',
    });
    final budgets = queue.create('replace_budgets', {
      'month': DateTime(2026, 9).toIso8601String(),
      'budgets': {'Food': 5000},
    });

    final expenseText = describeQueuedMutation(expense, _snapshot);
    expect(expenseText.title, 'Expense ৳250');
    expect(expenseText.detail, 'Food · from Cash · 12 Sep 2026');

    final loanText = describeQueuedMutation(loan, _snapshot);
    expect(loanText.title, 'Loan given ৳1,000');
    expect(loanText.detail, 'Rahim · bKash');

    expect(describeQueuedMutation(budgets, _snapshot).detail, 'September 2026');
    // Without a snapshot the ids are never shown.
    expect(describeQueuedMutation(loan, null).detail, 'a person · an account');
  });

  testWidgets('the dashboard flags failed changes and opens the review', (
    tester,
  ) async {
    final setup = await _setUp(failedCount: 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(user: _user, dataSource: setup.cache),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 change could not be saved.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.byType(UnsyncedChangesScreen), findsOneWidget);
    expect(find.text('Expense ৳250'), findsOneWidget);
    await setup.cache.close();
  });

  testWidgets('lists each failed change with its reason', (tester) async {
    final setup = await _setUp(failedCount: 2);
    await _pumpScreen(tester, setup.cache);

    expect(find.text("These changes weren't saved"), findsOneWidget);
    expect(find.text('Expense ৳250'), findsOneWidget);
    expect(find.text('Expense ৳251'), findsOneWidget);
    expect(
      find.text('An account, person or investment it uses was deleted.'),
      findsNWidgets(2),
    );
    expect(find.text('Try all 2 again'), findsOneWidget);
    await setup.cache.close();
  });

  testWidgets('discarding asks first, then removes only that change', (
    tester,
  ) async {
    final setup = await _setUp(failedCount: 2);
    await _pumpScreen(tester, setup.cache);

    await tester.tap(find.widgetWithText(TextButton, 'Discard').first);
    await tester.pumpAndSettle();
    expect(find.text('Discard this change?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense ৳250'), findsNothing);
    expect(find.text('Expense ৳251'), findsOneWidget);
    expect(setup.remote.executed, isEmpty);
    await setup.cache.close();
  });

  testWidgets('trying again syncs the change and clears the list', (
    tester,
  ) async {
    final setup = await _setUp(failedCount: 1);
    await _pumpScreen(tester, setup.cache);

    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(setup.remote.executed, [setup.failed.single.id]);
    expect(find.text('Nothing left to fix'), findsOneWidget);
    await setup.cache.close();
  });

  testWidgets('a change that fails again stays listed', (tester) async {
    final setup = await _setUp(failedCount: 1);
    setup.remote.error = _deletedReference;
    await _pumpScreen(tester, setup.cache);

    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(setup.remote.executed, [setup.failed.single.id]);
    expect(find.text('Expense ৳250'), findsOneWidget);
    await setup.cache.close();
  });

  for (final size in const [Size(320, 568), Size(1440, 900)]) {
    testWidgets('fits at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final setup = await _setUp(failedCount: 3);
      await _pumpScreen(tester, setup.cache);

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await setup.cache.close();
    });
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CachedMoneyDataSource cache,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: UnsyncedChangesScreen(dataSource: cache, snapshot: _snapshot),
    ),
  );
  await tester.pumpAndSettle();
}

class _Setup {
  const _Setup(this.cache, this.remote, this.failed);

  final CachedMoneyDataSource cache;
  final _FakeRemote remote;
  final List<QueuedMoneyMutation> failed;
}

/// A cache whose queue already holds [failedCount] failed expenses of
/// ৳250, ৳251, and so on.
Future<_Setup> _setUp({required int failedCount}) async {
  final store = MemoryDashboardCacheStore();
  final queue = _queue(store);
  final failed = [
    for (var index = 0; index < failedCount; index++)
      queue.create('money_out', {
        'amount': 250 + index,
        'account_id': 'cash',
        'category': 'Food',
        'occurred_at': toSupabaseTimestamp(DateTime(2026, 9, 12, 10)),
      }),
  ];
  for (final mutation in failed) {
    await queue.enqueue(mutation);
  }
  await queue.drain(_FailingExecutor());

  final remote = _FakeRemote();
  final cache = CachedMoneyDataSource(
    remote,
    cacheKey: 'user-1',
    staleAfter: const Duration(days: 1),
    cacheStore: store,
    mutationQueue: queue,
  );
  return _Setup(cache, remote, failed);
}

OfflineMutationQueue _queue([DashboardCacheStore? store]) {
  return OfflineMutationQueue(
    store: store ?? MemoryDashboardCacheStore(),
    key: 'unsynced-test',
  );
}

class _FailingExecutor implements IdempotentMoneyMutationExecutor {
  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    throw _deletedReference;
  }
}

class _FakeRemote implements MoneyDataSource, IdempotentMoneyMutationExecutor {
  final executed = <String>[];
  Object? error;

  @override
  Future<DashboardSnapshot> fetchDashboard() async => _snapshot;

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    executed.add(mutation.id);
    final failure = error;
    if (failure != null) throw failure;
  }

  // The screen and dashboard only read and sync; no direct writes happen.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _created = DateTime(2026, 1, 1);

final _snapshot = DashboardSnapshot(
  accounts: [
    Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: _created),
    Account(id: 'bkash', name: 'bKash', type: 'wallet', createdAt: _created),
  ],
  people: [Person(id: 'rahim', name: 'Rahim', createdAt: _created)],
  investments: const [],
  transactions: const [],
  budgets: const [],
);

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'me@example.com',
  createdAt: '2026-07-10T00:00:00.000Z',
);
