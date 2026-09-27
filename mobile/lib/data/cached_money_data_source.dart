import 'dart:async';
import 'dart:convert';

import '../core/date_times.dart';
import 'money_repository.dart';
import '../models/money_models.dart';
import 'offline_mutation_queue.dart';
import 'pending_mutations.dart';
import 'secure_cache_store.dart';

/// Keeps the last dashboard snapshot available while Supabase is contacted
/// only for the initial load, stale-data revalidation, or after a mutation.
class CachedMoneyDataSource
    implements MoneyDataSource, AdvancedMoneyDataSource {
  CachedMoneyDataSource(
    this.remote, {
    required this.cacheKey,
    this.staleAfter = const Duration(minutes: 5),
    DateTime Function()? clock,
    DashboardCacheStore? cacheStore,
    OfflineMutationQueue? mutationQueue,
  }) : _clock = clock ?? DateTime.now,
       _cacheStore = cacheStore ?? SecureDashboardCacheStore() {
    _mutationQueue =
        mutationQueue ??
        OfflineMutationQueue(
          store: _cacheStore,
          key: 'money_master.mutation_queue.$cacheKey',
          clock: _clock,
        );
  }

  final MoneyDataSource remote;
  final String cacheKey;
  final Duration staleAfter;
  final DateTime Function() _clock;
  final DashboardCacheStore _cacheStore;
  late final OfflineMutationQueue _mutationQueue;

  final StreamController<DashboardSnapshot> _snapshotChanges =
      StreamController<DashboardSnapshot>.broadcast();
  final StreamController<int> _statusChanges =
      StreamController<int>.broadcast();
  Future<void>? _hydrateFuture;
  Future<DashboardSnapshot>? _refreshFuture;
  DashboardSnapshot? _snapshot;
  DateTime? _lastSyncedAt;
  Object? _lastSyncError;
  bool _needsRemoteRefresh = false;
  bool _closed = false;
  bool _lastMutationQueued = false;
  int _statusRevision = 0;

  Stream<DashboardSnapshot> get snapshots => _snapshotChanges.stream;

  Stream<int> get statusChanges => _statusChanges.stream;

  /// The last snapshot, with changes still waiting to sync applied.
  DashboardSnapshot? get snapshot {
    final server = _snapshot;
    return server == null ? null : _withPending(server);
  }

  /// Whether the most recent change was kept on this device to sync later,
  /// rather than saved to the server straight away.
  bool get lastMutationQueued => _lastMutationQueued;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  Object? get lastSyncError => _lastSyncError;

  int get pendingMutationCount => _mutationQueue.pendingCount;

  int get failedMutationCount => _mutationQueue.failedCount;

  List<QueuedMoneyMutation> get failedMutations =>
      _mutationQueue.failedMutations;

  /// Puts failed changes back in the sync queue and tries to sync now. With
  /// [id], only that change. One that fails again for good returns to the
  /// failed list.
  Future<void> retryFailedMutations({String? id}) async {
    await _mutationQueue.retryFailed(id: id);
    _notifyStatus();
    await _drainQueue();
  }

  Future<void> discardFailedMutation(String id) async {
    await _mutationQueue.discardFailed(id);
    _notifyStatus();
  }

  bool get hasStaleData {
    final syncedAt = _lastSyncedAt;
    return _snapshot != null &&
        (_needsRemoteRefresh ||
            syncedAt == null ||
            _clock().difference(syncedAt) >= staleAfter);
  }

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    await _hydrate();
    await _mutationQueue.load();
    _drainQueueInBackground();

    final cached = _snapshot;
    if (cached != null) {
      if (_needsRemoteRefresh) return refresh();
      if (hasStaleData) _refreshInBackground();
      return _withPending(cached);
    }

    return refresh();
  }

  Future<DashboardSnapshot> refresh() async {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _fetchAndStore();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    }
  }

  Future<DashboardSnapshot> _fetchAndStore() async {
    try {
      final fresh = await remote.fetchDashboard();
      _snapshot = fresh;
      _lastSyncedAt = _clock();
      _lastSyncError = null;
      _needsRemoteRefresh = false;
      await _persist(fresh);
      _notifyStatus();
      final shown = _withPending(fresh);
      if (!_closed) _snapshotChanges.add(shown);
      return shown;
    } catch (error) {
      _lastSyncError = error;
      _needsRemoteRefresh = true;
      _notifyStatus();
      final cached = _snapshot;
      if (cached != null) return _withPending(cached);
      rethrow;
    }
  }

  // Only the server's own snapshot is persisted; pending changes live in the
  // queue and are applied on top whenever a snapshot is handed out.
  DashboardSnapshot _withPending(DashboardSnapshot server) {
    return applyPendingMutations(server, _mutationQueue.pendingMutations);
  }

  /// Sends the current snapshot, with pending changes applied, to listeners.
  /// Needed whenever the queue changes without a successful refresh, which
  /// is the only other thing that sends one.
  void _publish() {
    final server = _snapshot;
    if (server != null && !_closed) {
      _snapshotChanges.add(_withPending(server));
    }
  }

  void _refreshInBackground() {
    unawaited(() async {
      try {
        await refresh();
      } catch (_) {
        // Existing cached data remains usable while the device is offline.
      }
    }());
  }

  Future<void> _hydrate() {
    return _hydrateFuture ??= _readPersistedSnapshot();
  }

  Future<void> _readPersistedSnapshot() async {
    try {
      final raw = await _cacheStore.read(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final envelope = jsonDecode(raw);
      if (envelope is! Map) return;
      if (envelope['version'] != 1 || envelope['snapshot'] is! Map) return;

      _snapshot = DashboardSnapshot.fromJson(
        Map<String, dynamic>.from(envelope['snapshot'] as Map),
      );
      _lastSyncedAt = DateTime.tryParse(envelope['saved_at']?.toString() ?? '');
    } catch (_) {
      // A corrupt cache should never prevent a fresh sign-in from loading.
      _snapshot = null;
      _lastSyncedAt = null;
    }
  }

  Future<void> _persist(DashboardSnapshot snapshot) async {
    try {
      await _cacheStore.write(
        _prefsKey,
        jsonEncode({
          'version': 1,
          'saved_at': _lastSyncedAt?.toIso8601String(),
          'snapshot': snapshot.toJson(),
        }),
      );
    } catch (_) {
      // Persistence is an optimization; a storage failure must not fail CRUD.
    }
  }

  String get _prefsKey => 'money_master.dashboard_cache.$cacheKey';

  Future<void> _mutate({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    // remote is always a MoneyRepository in production, which implements
    // IdempotentMoneyMutationExecutor — every mutation goes through the
    // offline-capable queue path.
    final executor = remote as IdempotentMoneyMutationExecutor;
    final mutation = _mutationQueue.create(kind, payload);
    try {
      await executor.executeMutation(mutation);
      _lastMutationQueued = false;
    } catch (error) {
      if (!isRetryableMutationError(error)) rethrow;
      await _mutationQueue.enqueue(mutation);
      _lastMutationQueued = true;
      // Show it right away; the refresh that follows will fail offline.
      _publish();
    }

    _needsRemoteRefresh = true;
    _notifyStatus();
  }

  void _drainQueueInBackground() => unawaited(_drainQueue());

  Future<void> _drainQueue() async {
    final executor = remote;
    if (executor is! IdempotentMoneyMutationExecutor ||
        _mutationQueue.pendingCount == 0) {
      return;
    }
    final mutationExecutor = executor as IdempotentMoneyMutationExecutor;

    try {
      final applied = await _mutationQueue.drain(mutationExecutor);
      if (applied > 0) {
        _needsRemoteRefresh = true;
        await refresh();
      }
    } catch (_) {
      // Truly unexpected errors only; mutation failures are either kept
      // queued or moved to the failed list by drain() and don't throw here.
    } finally {
      // Changes moved to the failed list are no longer shown as pending.
      _publish();
      _notifyStatus();
    }
  }

  void _notifyStatus() {
    if (!_closed) _statusChanges.add(++_statusRevision);
  }

  @override
  Future<TransactionPage> fetchTransactionPage({
    TransactionCursor? before,
    int limit = 100,
  }) async {
    final source = remote;
    if (source is AdvancedMoneyDataSource) {
      return (source as AdvancedMoneyDataSource).fetchTransactionPage(
        before: before,
        limit: limit,
      );
    }

    final transactions = [...?_snapshot?.transactions]
      ..sort((a, b) {
        final dateCompare = b.occurredAt.compareTo(a.occurredAt);
        return dateCompare != 0 ? dateCompare : b.id.compareTo(a.id);
      });
    final filtered = before == null
        ? transactions
        : transactions.where((item) {
            final dateCompare = item.occurredAt.compareTo(before.occurredAt);
            return dateCompare < 0 ||
                (dateCompare == 0 && item.id.compareTo(before.id) < 0);
          }).toList();
    final items = filtered.take(limit).toList();
    final last = items.lastOrNull;
    return TransactionPage(
      items: items,
      nextCursor: last == null
          ? null
          : TransactionCursor(occurredAt: last.occurredAt, id: last.id),
      hasMore: filtered.length > items.length,
    );
  }

  @override
  Future<DashboardServerSummary?> fetchServerSummary(DateTime month) {
    final source = remote;
    if (source is AdvancedMoneyDataSource) {
      return (source as AdvancedMoneyDataSource).fetchServerSummary(month);
    }
    return Future<DashboardServerSummary?>.value();
  }

  @override
  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) => _mutate(
    kind: 'money_in',
    payload: {
      'amount': amount,
      'account_id': accountId,
      'category': category,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'note': note,
    },
  );

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) => _mutate(
    kind: 'money_out',
    payload: {
      'amount': amount,
      'account_id': accountId,
      'category': category,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'note': note,
    },
  );

  @override
  Future<void> createTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  }) => _mutate(
    kind: 'transfer',
    payload: {
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'note': note,
    },
  );

  @override
  Future<void> createPerson({
    required String name,
    String? phone,
    String? note,
  }) => _mutate(
    kind: 'create_person',
    payload: {'name': name, 'phone': phone, 'note': note},
  );

  @override
  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
  }) => _mutate(
    kind: 'update_person',
    payload: {
      'person_id': personId,
      'name': name,
      'phone': phone,
      'note': note,
    },
  );

  @override
  Future<void> deletePerson(String personId) =>
      _mutate(kind: 'delete_person', payload: {'person_id': personId});

  @override
  Future<void> updateAccount({
    required String accountId,
    required String name,
    required double adjustmentAmount,
    required bool addMoney,
    String? note,
  }) => _mutate(
    kind: 'update_account',
    payload: {
      'account_id': accountId,
      'name': name,
      'adjustment_amount': adjustmentAmount,
      'add_money': addMoney,
      'note': note,
    },
  );

  @override
  Future<void> createLoanTransaction({
    required String type,
    required double amount,
    required String accountId,
    required String personId,
    required DateTime occurredAt,
    String? note,
  }) => _mutate(
    kind: 'loan',
    payload: {
      'type': type,
      'amount': amount,
      'account_id': accountId,
      'person_id': personId,
      'category': switch (type) {
        'borrow' => 'Borrowed Money',
        'lend' => 'Loan Given',
        'repay' => 'Loan Repayment',
        'receive' => 'Loan Received Back',
        _ => 'Loan',
      },
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'note': note,
    },
  );

  @override
  Future<void> createInvestment({
    required String name,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? description,
    String? note,
  }) => _mutate(
    kind: 'create_investment',
    payload: {
      'name': name,
      'amount': amount,
      'from_account_id': fromAccountId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'description': description,
      'note': note,
    },
  );

  @override
  Future<void> addInvestmentFunds({
    required String investmentId,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? note,
  }) => _mutate(
    kind: 'add_investment_funds',
    payload: {
      'investment_id': investmentId,
      'amount': amount,
      'from_account_id': fromAccountId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'note': note,
    },
  );

  @override
  Future<void> recordInvestmentReturn({
    required String investmentId,
    required double amount,
    required String toAccountId,
    required DateTime occurredAt,
    required bool closeInvestment,
    String? note,
  }) => _mutate(
    kind: 'investment_return',
    payload: {
      'investment_id': investmentId,
      'amount': amount,
      'to_account_id': toAccountId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'close_investment': closeInvestment,
      'note': note,
    },
  );

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
  }) {
    final transfer = transaction.type == 'transfer';
    final moneyIn = transaction.isIncomeLike;
    final fromAccountId = transfer || !moneyIn ? accountId : null;
    final effectiveToAccountId = transfer
        ? toAccountId
        : moneyIn
        ? accountId
        : null;

    return _mutate(
      kind: 'update_transaction',
      payload: {
        'transaction_id': transaction.id,
        'transaction': transaction.toJson(),
        'amount': amount,
        'occurred_at': toSupabaseTimestamp(occurredAt),
        'account_id': accountId,
        'from_account_id': fromAccountId,
        'to_account_id': effectiveToAccountId,
        'person_id': personId,
        'category': transfer ? 'Transfer' : category,
        'note': note,
      },
    );
  }

  @override
  Future<void> replaceBudgetsForMonth({
    required DateTime month,
    required Map<String, double> budgets,
  }) => _mutate(
    kind: 'replace_budgets',
    payload: {
      'month': DateTime(month.year, month.month).toIso8601String(),
      'budgets': budgets,
    },
  );

  @override
  Future<void> clearBudgetsForMonth(DateTime month) => _mutate(
    kind: 'clear_budgets',
    payload: {'month': DateTime(month.year, month.month).toIso8601String()},
  );

  @override
  Future<void> deleteInvestment(String investmentId) => _mutate(
    kind: 'delete_investment',
    payload: {'investment_id': investmentId},
  );

  @override
  Future<void> deleteTransaction(String transactionId) => _mutate(
    kind: 'delete_transaction',
    payload: {'transaction_id': transactionId},
  );

  Future<void> close() async {
    _closed = true;
    await _snapshotChanges.close();
    await _statusChanges.close();
  }
}
