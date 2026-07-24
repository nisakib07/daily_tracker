import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('financial cache is encrypted at rest and decrypts correctly', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SecureDashboardCacheStore(
      keyStore: MemorySecureKeyStore(),
      preferences: preferences,
    );
    const storageKey = 'secure-cache-test';
    const financialJson = '{"balance":43645,"note":"private finance"}';

    await store.write(storageKey, financialJson);

    final stored = preferences.getString(storageKey);
    expect(stored, isNotNull);
    expect(stored, isNot(contains('43645')));
    expect(stored, isNot(contains('private finance')));
    expect(await store.read(storageKey), financialJson);
  });

  test('offline queue retains retryable writes and drains them once', () async {
    final store = MemoryDashboardCacheStore();
    final queue = OfflineMutationQueue(store: store, key: 'offline-queue');
    final mutation = queue.create('money_in', {'amount': 25});
    await queue.enqueue(mutation);
    await queue.enqueue(mutation);

    final executor = _RecordingExecutor(online: false);
    expect(await queue.drain(executor), 0);
    expect(queue.pendingCount, 1);

    executor.online = true;
    expect(await queue.drain(executor), 1);
    expect(queue.pendingCount, 0);
    expect(executor.appliedIds, [mutation.id]);
  });

  test(
    'offline queue survives recreation from encrypted storage contract',
    () async {
      final store = MemoryDashboardCacheStore();
      final first = OfflineMutationQueue(store: store, key: 'persistent-queue');
      final mutation = first.create('delete_transaction', {
        'transaction_id': 'transaction-1',
      });
      await first.enqueue(mutation);

      final restored = OfflineMutationQueue(
        store: store,
        key: 'persistent-queue',
      );
      await restored.load();

      expect(restored.pendingCount, 1);
      final executor = _RecordingExecutor(online: true);
      await restored.drain(executor);
      expect(executor.appliedIds, [mutation.id]);
    },
  );
}

class _RecordingExecutor implements IdempotentMoneyMutationExecutor {
  _RecordingExecutor({required this.online});

  bool online;
  final List<String> appliedIds = [];

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    if (!online) throw ClientException('offline');
    appliedIds.add(mutation.id);
  }
}
