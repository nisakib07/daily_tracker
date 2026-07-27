import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a non-retryable failure is dead-lettered instead of blocking '
      'mutations queued after it', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final poison = queue.create('delete_transaction', {'id': 'gone'});
    final healthy = queue.create('delete_transaction', {'id': 'ok'});
    await queue.enqueue(poison);
    await queue.enqueue(healthy);

    final executor = _FakeExecutor({
      poison.id: const PostgrestException(message: 'row not found'),
    });

    final applied = await queue.drain(executor);

    expect(applied, 1);
    expect(executor.executed, [poison.id, healthy.id]);
    expect(queue.pendingCount, 0);
    expect(queue.failedCount, 1);
    expect(queue.failedMutations.single.id, poison.id);
  });

  test('a retryable failure stops draining and leaves the mutation at the '
      'head of the queue for the next attempt', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'test-queue');

    final offline = queue.create('delete_transaction', {'id': 'a'});
    final later = queue.create('delete_transaction', {'id': 'b'});
    await queue.enqueue(offline);
    await queue.enqueue(later);

    final executor = _FakeExecutor({offline.id: TimeoutException('offline')});
    final applied = await queue.drain(executor);

    expect(applied, 0);
    expect(executor.executed, [offline.id]);
    expect(queue.pendingCount, 2);
    expect(queue.failedCount, 0);
  });

  test(
    'the failed list survives a fresh queue instance over the same store',
    () async {
      final store = MemoryDashboardCacheStore();
      final first = OfflineMutationQueue(store: store, key: 'test-queue');
      final poison = first.create('delete_transaction', {'id': 'gone'});
      await first.enqueue(poison);
      await first.drain(
        _FakeExecutor({
          poison.id: const PostgrestException(message: 'row not found'),
        }),
      );

      final second = OfflineMutationQueue(store: store, key: 'test-queue');
      await second.load();

      expect(second.pendingCount, 0);
      expect(second.failedCount, 1);
      expect(second.failedMutations.single.id, poison.id);
    },
  );
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
