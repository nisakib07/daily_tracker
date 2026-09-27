import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _deletedReference = PostgrestException(
  message: 'insert or update violates foreign key constraint',
  code: '23503',
);
const _serverError = PostgrestException(
  message: 'Service Unavailable',
  code: '503',
);

void main() {
  test('a permanent failure is dead-lettered instead of blocking '
      'mutations queued after it', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final poison = queue.create('delete_transaction', {'id': 'gone'});
    final healthy = queue.create('delete_transaction', {'id': 'ok'});
    await queue.enqueue(poison);
    await queue.enqueue(healthy);

    final executor = _FakeExecutor({poison.id: _deletedReference});

    final applied = await queue.drain(executor);

    expect(applied, 1);
    expect(executor.executed, [poison.id, healthy.id]);
    expect(queue.pendingCount, 0);
    expect(queue.failedCount, 1);
    final failed = queue.failedMutations.single;
    expect(failed.id, poison.id);
    expect(failed.attempts, 1);
    expect(
      failed.failureReason,
      'An account, person or investment it uses was deleted.',
    );
  });

  test('an offline failure stops draining and leaves the mutation at the '
      'head of the queue for the next attempt', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final offline = queue.create('delete_transaction', {'id': 'a'});
    final later = queue.create('delete_transaction', {'id': 'b'});
    await queue.enqueue(offline);
    await queue.enqueue(later);

    for (final error in <Object>[
      TimeoutException('offline'),
      AuthRetryableFetchException(message: 'Failed host lookup'),
    ]) {
      final executor = _FakeExecutor({offline.id: error});
      final applied = await queue.drain(executor);

      expect(applied, 0);
      expect(executor.executed, [offline.id]);
      expect(queue.pendingCount, 2);
      expect(queue.failedCount, 0);
    }
    // Being offline is not counted against the mutation.
    await queue.drain(_FakeExecutor({}));
    expect(queue.pendingCount, 0);
  });

  test('a server error keeps the mutation queued in order until it has '
      'failed maxAttempts times, then moves it aside', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final flaky = queue.create('money_out', {'amount': 250});
    final later = queue.create('money_out', {'amount': 40});
    await queue.enqueue(flaky);
    await queue.enqueue(later);

    final executor = _FakeExecutor({flaky.id: _serverError});
    for (
      var attempt = 1;
      attempt < OfflineMutationQueue.maxAttempts;
      attempt++
    ) {
      expect(await queue.drain(executor), 0);
      expect(queue.pendingCount, 2);
      expect(queue.failedCount, 0);
    }
    // The mutation behind it never ran while it was being retried.
    expect(executor.executed, everyElement(flaky.id));

    expect(await queue.drain(executor), 1);
    expect(executor.executed.last, later.id);
    expect(queue.pendingCount, 0);
    final failed = queue.failedMutations.single;
    expect(failed.id, flaky.id);
    expect(failed.attempts, OfflineMutationQueue.maxAttempts);
    expect(
      failed.failureReason,
      'The server refused it ${OfflineMutationQueue.maxAttempts} times.',
    );
  });

  test('an error without a code is retried rather than dropped at once', () {
    expect(
      isPermanentMutationError(const PostgrestException(message: 'oops')),
      isFalse,
    );
    expect(isPermanentMutationError(_serverError), isFalse);
    expect(isPermanentMutationError(_deletedReference), isTrue);
    expect(
      isPermanentMutationError(
        const PostgrestException(message: 'bad uuid', code: '22P02'),
      ),
      isTrue,
    );
    expect(
      isPermanentMutationError(
        const PostgrestException(
          message: 'No matching transaction was updated.',
          code: 'P0002',
        ),
      ),
      isTrue,
    );
  });

  test('retryFailed puts failed mutations back at the front, in their '
      'original order, with a fresh attempt count', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final first = queue.create('money_out', {'amount': 1});
    final second = queue.create('money_out', {'amount': 2});
    await queue.enqueue(first);
    await queue.enqueue(second);
    await queue.drain(
      _FakeExecutor({
        first.id: _deletedReference,
        second.id: _deletedReference,
      }),
    );
    expect(queue.failedCount, 2);

    final pendingLater = queue.create('money_out', {'amount': 3});
    await queue.enqueue(pendingLater);

    await queue.retryFailed();
    expect(queue.failedCount, 0);
    expect(queue.pendingCount, 3);

    final executor = _FakeExecutor({});
    expect(await queue.drain(executor), 3);
    expect(executor.executed, [first.id, second.id, pendingLater.id]);
  });

  test('retryFailed with an id and discardFailed each touch one '
      'mutation, and both are persisted', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final keep = queue.create('money_out', {'amount': 1});
    final retry = queue.create('money_out', {'amount': 2});
    final discard = queue.create('money_out', {'amount': 3});
    for (final mutation in [keep, retry, discard]) {
      await queue.enqueue(mutation);
    }
    await queue.drain(
      _FakeExecutor({
        keep.id: _deletedReference,
        retry.id: _deletedReference,
        discard.id: _deletedReference,
      }),
    );

    await queue.retryFailed(id: retry.id);
    await queue.discardFailed(discard.id);

    final reloaded = OfflineMutationQueue(store: store, key: 'test-queue');
    await reloaded.load();
    expect(reloaded.failedMutations.map((item) => item.id), [keep.id]);
    expect(reloaded.pendingCount, 1);
    final executor = _FakeExecutor({});
    await reloaded.drain(executor);
    expect(executor.executed, [retry.id]);
    expect(reloaded.failedMutations.single.attempts, 1);
  });

  test(
    'the failed list survives a fresh queue instance over the same store',
    () async {
      final store = MemoryDashboardCacheStore();
      final first = OfflineMutationQueue(store: store, key: 'test-queue');
      final poison = first.create('delete_transaction', {'id': 'gone'});
      await first.enqueue(poison);
      await first.drain(_FakeExecutor({poison.id: _deletedReference}));

      final second = OfflineMutationQueue(store: store, key: 'test-queue');
      await second.load();

      expect(second.pendingCount, 0);
      expect(second.failedCount, 1);
      expect(second.failedMutations.single.id, poison.id);
      expect(
        second.failedMutations.single.failureReason,
        'An account, person or investment it uses was deleted.',
      );
    },
  );

  test('mutations saved before attempts were tracked still load', () async {
    final store = MemoryDashboardCacheStore();
    await store.write(
      'test-queue',
      jsonEncode([
        {
          'id': 'old-1',
          'kind': 'money_in',
          'payload': {'amount': 10},
          'created_at': '2026-09-01T10:00:00.000',
        },
      ]),
    );

    final queue = OfflineMutationQueue(store: store, key: 'test-queue');
    await queue.load();

    expect(queue.pendingCount, 1);
    final executor = _FakeExecutor({'old-1': _serverError});
    await queue.drain(executor);
    expect(queue.pendingCount, 1);
    expect(queue.failedCount, 0);
  });
}

class _FakeExecutor implements IdempotentMoneyMutationExecutor {
  _FakeExecutor(this._errors);

  final Map<String, Object> _errors;
  final List<String> executed = [];

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    executed.add(mutation.id);
    final error = _errors[mutation.id];
    if (error != null) throw error;
  }
}
