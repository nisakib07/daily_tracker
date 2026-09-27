import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/cached_money_data_source.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/models/money_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses the in-memory snapshot without another remote fetch', () async {
    final remote = _FakeMoneyDataSource(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'memory-read',
      staleAfter: const Duration(days: 1),
      cacheStore: MemoryDashboardCacheStore(),
    );

    final first = await cache.fetchDashboard();
    final second = await cache.fetchDashboard();

    expect(first.transactions, hasLength(1));
    expect(second.transactions, hasLength(1));
    expect(remote.fetchCount, 1);
    await cache.close();
  });

  test('hydrates persisted data without blocking on a remote fetch', () async {
    final store = MemoryDashboardCacheStore();
    final firstRemote = _FakeMoneyDataSource(_snapshot(amount: 10));
    final firstCache = CachedMoneyDataSource(
      firstRemote,
      cacheKey: 'persisted-read',
      staleAfter: const Duration(days: 1),
      cacheStore: store,
    );
    await firstCache.fetchDashboard();
    await firstCache.close();

    final secondRemote = _FakeMoneyDataSource(_snapshot(amount: 20));
    final secondCache = CachedMoneyDataSource(
      secondRemote,
      cacheKey: 'persisted-read',
      staleAfter: const Duration(days: 1),
      cacheStore: store,
    );
    final cached = await secondCache.fetchDashboard();

    expect(cached.transactions.single.amount, 10);
    expect(secondRemote.fetchCount, 0);
    await secondCache.close();
  });

  test('a successful CRUD operation invalidates the cache once', () async {
    final remote = _FakeMoneyDataSource(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'mutation-invalidation',
      staleAfter: const Duration(days: 1),
      cacheStore: MemoryDashboardCacheStore(),
    );

    await cache.fetchDashboard();
    await cache.createMoneyIn(
      amount: 25,
      accountId: 'cash',
      category: 'Test',
      occurredAt: DateTime(2026, 7, 10),
    );
    await cache.fetchDashboard();

    expect(remote.createMoneyInCount, 1);
    expect(remote.fetchCount, 2);
    await cache.close();
  });

  test('concurrent refreshes share one remote request', () async {
    final remote = _BlockingMoneyDataSource(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'dedupe',
      cacheStore: MemoryDashboardCacheStore(),
    );

    final first = cache.refresh();
    final second = cache.refresh();
    expect(remote.fetchCount, 1);

    remote.complete();
    expect((await Future.wait([first, second])).length, 2);
    await cache.close();
  });

  test('failed changes are exposed and a retry syncs them and refreshes the '
      'snapshot', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'failed-retry');
    final failed = queue.create('money_in', {'amount': 25});
    await queue.enqueue(failed);
    await queue.drain(
      _ScriptedExecutor(const PostgrestException(message: 'fk', code: '23503')),
    );

    final remote = _FakeMoneyDataSource(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'failed-retry',
      staleAfter: const Duration(days: 1),
      cacheStore: store,
      mutationQueue: queue,
    );
    await cache.fetchDashboard();
    expect(cache.failedMutationCount, 1);
    expect(cache.failedMutations.single.id, failed.id);

    final statusEvents = <int>[];
    final subscription = cache.statusChanges.listen(statusEvents.add);
    await cache.retryFailedMutations(id: failed.id);
    await Future<void>.delayed(Duration.zero);

    expect(remote.createMoneyInCount, 1);
    expect(cache.failedMutationCount, 0);
    expect(cache.pendingMutationCount, 0);
    expect(remote.fetchCount, 2);
    expect(statusEvents, isNotEmpty);
    await subscription.cancel();
    await cache.close();
  });

  test('discarding a failed change removes it for good', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'failed-discard');
    final failed = queue.create('money_in', {'amount': 25});
    await queue.enqueue(failed);
    await queue.drain(
      _ScriptedExecutor(const PostgrestException(message: 'fk', code: '23503')),
    );

    final remote = _FakeMoneyDataSource(_snapshot());
    final cache = CachedMoneyDataSource(
      remote,
      cacheKey: 'failed-discard',
      staleAfter: const Duration(days: 1),
      cacheStore: store,
      mutationQueue: queue,
    );
    await cache.fetchDashboard();
    await cache.discardFailedMutation(failed.id);

    expect(cache.failedMutationCount, 0);
    expect(remote.createMoneyInCount, 0);
    final reloaded = OfflineMutationQueue(store: store, key: 'failed-discard');
    await reloaded.load();
    expect(reloaded.failedCount, 0);
    await cache.close();
  });

  test(
    'large snapshots round-trip all transactions through the cache codec',
    () {
      final now = DateTime(2026, 7, 10);
      final snapshot = DashboardSnapshot(
        accounts: [_account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: List.generate(
          5000,
          (index) => TransactionRecord(
            id: 'transaction-$index',
            type: index.isEven ? 'income' : 'expense',
            amount: index + 1,
            fromAccountId: index.isEven ? null : 'cash',
            toAccountId: index.isEven ? 'cash' : null,
            category: 'Stress test',
            occurredAt: now.subtract(Duration(minutes: index)),
            createdAt: now.subtract(Duration(minutes: index)),
          ),
        ),
      );

      final restored = DashboardSnapshot.fromJson(snapshot.toJson());

      expect(restored.transactions, hasLength(5000));
      expect(restored.transactions.last.id, 'transaction-4999');
    },
  );
}

final _account = Account(
  id: 'cash',
  name: 'Cash',
  type: 'cash',
  createdAt: DateTime(2026, 1, 1),
);

DashboardSnapshot _snapshot({double amount = 100}) {
  final now = DateTime(2026, 7, 10, 10);
  return DashboardSnapshot(
    accounts: [_account],
    people: const [],
    investments: const [],
    budgets: const [],
    transactions: [
      TransactionRecord(
        id: 'transaction-1',
        type: 'income',
        amount: amount,
        toAccountId: _account.id,
        category: 'Test',
        occurredAt: now,
        createdAt: now,
      ),
    ],
  );
}

class _FakeMoneyDataSource
    implements MoneyDataSource, IdempotentMoneyMutationExecutor {
  _FakeMoneyDataSource(this.snapshot);

  DashboardSnapshot snapshot;
  int fetchCount = 0;
  int createMoneyInCount = 0;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    fetchCount++;
    return snapshot;
  }

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    if (mutation.kind == 'money_in') createMoneyInCount++;
  }

  @override
  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    createMoneyInCount++;
  }

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) => _unsupported();

  @override
  Future<void> createTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  }) => _unsupported();

  @override
  Future<void> createPerson({
    required String name,
    String? phone,
    String? note,
  }) => _unsupported();

  @override
  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
  }) => _unsupported();

  @override
  Future<void> deletePerson(String personId) => _unsupported();

  @override
  Future<void> updateAccount({
    required String accountId,
    required String name,
    required double adjustmentAmount,
    required bool addMoney,
    String? note,
  }) => _unsupported();

  @override
  Future<void> createLoanTransaction({
    required String type,
    required double amount,
    required String accountId,
    required String personId,
    required DateTime occurredAt,
    String? note,
  }) => _unsupported();

  @override
  Future<void> createInvestment({
    required String name,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? description,
    String? note,
  }) => _unsupported();

  @override
  Future<void> addInvestmentFunds({
    required String investmentId,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? note,
  }) => _unsupported();

  @override
  Future<void> recordInvestmentReturn({
    required String investmentId,
    required double amount,
    required String toAccountId,
    required DateTime occurredAt,
    required bool closeInvestment,
    String? note,
  }) => _unsupported();

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
  }) => _unsupported();

  @override
  Future<void> replaceBudgetsForMonth({
    required DateTime month,
    required Map<String, double> budgets,
  }) => _unsupported();

  @override
  Future<void> clearBudgetsForMonth(DateTime month) => _unsupported();

  @override
  Future<void> deleteInvestment(String investmentId) => _unsupported();

  @override
  Future<void> deleteTransaction(String transactionId) => _unsupported();

  Future<void> _unsupported() async {
    throw UnimplementedError();
  }
}

class _ScriptedExecutor implements IdempotentMoneyMutationExecutor {
  _ScriptedExecutor(this.error);

  final Object error;

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    throw error;
  }
}

class _BlockingMoneyDataSource extends _FakeMoneyDataSource {
  _BlockingMoneyDataSource(super.snapshot);

  final Completer<DashboardSnapshot> _completer =
      Completer<DashboardSnapshot>();

  @override
  Future<DashboardSnapshot> fetchDashboard() {
    fetchCount++;
    return _completer.future;
  }

  void complete() => _completer.complete(snapshot);
}
