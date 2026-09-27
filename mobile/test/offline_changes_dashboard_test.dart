import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/date_times.dart';
import 'package:money_master/data/cached_money_data_source.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/pending_mutations.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/features/dashboard/dashboard_screen.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('a transaction added offline is marked and has no actions', (
    tester,
  ) async {
    _useTallView(tester);
    final queue = OfflineMutationQueue(
      store: MemoryDashboardCacheStore(),
      key: 'dashboard-pending',
    );
    final offlineExpense = queue.create('money_out', {
      'amount': 75,
      'account_id': 'cash',
      'category': 'Rickshaw',
      'occurred_at': toSupabaseTimestamp(DateTime.now()),
    });
    final shown = applyPendingMutations(_snapshot(), [offlineExpense]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(user: _user, snapshotLoader: () async => shown),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rickshaw'), findsWidgets);
    expect(find.text('Waiting to sync'), findsOneWidget);
    // Only the transaction that exists on the server can be edited/deleted.
    expect(find.byTooltip('Transaction actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting offline removes it at once and says it will sync', (
    tester,
  ) async {
    _useTallView(tester);
    final remote = _FakeRemote(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'user-1',
      staleAfter: const Duration(days: 1),
      cacheStore: MemoryDashboardCacheStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(user: _user, dataSource: cache),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tea stall'), findsWidgets);

    remote.offline = true;
    await tester.tap(find.byTooltip('Transaction actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Tea stall'), findsNothing);
    expect(
      find.text(
        'Transaction deleted on this phone. It will sync when you are back '
        'online.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 change waiting to sync.'), findsOneWidget);
    await cache.close();
  });

  testWidgets('signing out with unsynced changes asks first', (tester) async {
    _useTallView(tester);
    final remote = _FakeRemote(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'user-1',
      staleAfter: const Duration(days: 1),
      cacheStore: MemoryDashboardCacheStore(),
    );
    await cache.fetchDashboard();
    remote.offline = true;
    await cache.createMoneyOut(
      amount: 60,
      accountId: 'cash',
      category: 'Snacks',
      occurredAt: DateTime.now(),
    );
    var signOuts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(
          user: _user,
          dataSource: cache,
          signOut: () async => signOuts++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> chooseSignOut() async {
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
    }

    await chooseSignOut();
    expect(find.text('Sign out with unsynced changes?'), findsOneWidget);
    expect(
      find.textContaining("1 change hasn't reached the server"),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(signOuts, 0);

    await chooseSignOut();
    await tester.tap(find.text('Sign out anyway'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    await cache.close();
  });

  testWidgets('with everything synced, sign out needs no confirmation', (
    tester,
  ) async {
    _useTallView(tester);
    final cache = CachedMoneyDataSource(
      _FakeRemote(_snapshot()),
      cacheKey: 'user-1',
      staleAfter: const Duration(days: 1),
      cacheStore: MemoryDashboardCacheStore(),
    );
    var signOuts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(
          user: _user,
          dataSource: cache,
          signOut: () async => signOuts++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out with unsynced changes?'), findsNothing);
    expect(signOuts, 1);
    await cache.close();
  });
}

void _useTallView(WidgetTester tester) {
  // Tall enough that the Activity list is built without scrolling.
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeRemote implements MoneyDataSource, IdempotentMoneyMutationExecutor {
  _FakeRemote(this.snapshot);

  final DashboardSnapshot snapshot;
  bool offline = false;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    if (offline) throw TimeoutException('offline');
    return snapshot;
  }

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    if (offline) throw TimeoutException('offline');
  }

  // Everything else goes through executeMutation via the cache.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _created = DateTime(2026, 1, 1);

DashboardSnapshot _snapshot() {
  final now = DateTime.now();
  return DashboardSnapshot(
    accounts: [
      Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: _created),
    ],
    people: const [],
    investments: const [],
    budgets: const [],
    transactions: [
      TransactionRecord(
        id: 'tea',
        type: 'expense',
        amount: 20,
        fromAccountId: 'cash',
        category: 'Tea stall',
        occurredAt: now,
        createdAt: now,
      ),
    ],
  );
}

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'me@example.com',
  createdAt: '2026-07-10T00:00:00.000Z',
);
