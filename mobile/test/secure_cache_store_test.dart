import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('concurrent writes on a fresh store share one bootstrapped key instead '
      'of racing to generate and persist separate ones', () async {
    final store = SecureDashboardCacheStore(keyStore: MemorySecureKeyStore());

    // Both calls hit the "no key yet" branch of _loadKey before either
    // finishes bootstrapping one, since neither has awaited yet when the
    // second call starts.
    await Future.wait([
      store.write('entry-a', 'value-a'),
      store.write('entry-b', 'value-b'),
    ]);

    expect(await store.read('entry-a'), 'value-a');
    expect(await store.read('entry-b'), 'value-b');
  });

  test('a value written before the key is bootstrapped is still readable '
      'from a second store instance sharing the same key store', () async {
    final keyStore = MemorySecureKeyStore();
    final prefs = await SharedPreferences.getInstance();

    final first = SecureDashboardCacheStore(
      keyStore: keyStore,
      preferences: prefs,
    );
    await Future.wait([
      first.write('entry-a', 'value-a'),
      first.write('entry-b', 'value-b'),
    ]);

    final second = SecureDashboardCacheStore(
      keyStore: keyStore,
      preferences: prefs,
    );
    expect(await second.read('entry-a'), 'value-a');
    expect(await second.read('entry-b'), 'value-b');
  });
}
