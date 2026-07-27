import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DashboardCacheStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

abstract interface class SecureKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class PlatformSecureKeyStore implements SecureKeyStore {
  PlatformSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Stores large cache payloads in preferences after AES-256-GCM encryption.
/// The encryption key itself stays in the platform's secure key store.
class SecureDashboardCacheStore implements DashboardCacheStore {
  SecureDashboardCacheStore({
    SecureKeyStore? keyStore,
    SharedPreferences? preferences,
  }) : _keyStore = keyStore ?? PlatformSecureKeyStore(),
       // ignore: prefer_initializing_formals
       _preferences = preferences;

  static const _keyName = 'money_master.cache_encryption_key.v1';
  static const _version = 1;

  final SecureKeyStore _keyStore;
  final SharedPreferences? _preferences;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _secretKey;
  Future<SecretKey>? _keyFuture;

  @override
  Future<String?> read(String key) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final envelope = jsonDecode(encoded);
      if (envelope is! Map || envelope['v'] != _version) {
        await prefs.remove(key);
        return null;
      }

      final secretBox = SecretBox(
        base64Decode(envelope['ciphertext'].toString()),
        nonce: base64Decode(envelope['nonce'].toString()),
        mac: Mac(base64Decode(envelope['mac'].toString())),
      );
      final clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: await _loadKey(),
        aad: utf8.encode(key),
      );
      return utf8.decode(clearBytes);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final secretBox = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: await _loadKey(),
      nonce: _cipher.newNonce(),
      aad: utf8.encode(key),
    );

    await prefs.setString(
      key,
      jsonEncode({
        'v': _version,
        'nonce': base64Encode(secretBox.nonce),
        'ciphertext': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      }),
    );
  }

  @override
  Future<void> delete(String key) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<SecretKey> _loadKey() {
    final existing = _secretKey;
    if (existing != null) return Future.value(existing);
    // Memoize the in-flight load/create so concurrent read()/write() calls
    // on first run await the same key instead of racing to each generate
    // and persist their own, which would leave one caller silently unable
    // to decrypt what the other wrote.
    return _keyFuture ??= _loadOrCreateKey();
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final encoded = await _keyStore.read(_keyName);
    if (encoded != null && encoded.isNotEmpty) {
      final key = SecretKey(base64Decode(encoded));
      _secretKey = key;
      return key;
    }

    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    await _keyStore.write(_keyName, base64Encode(bytes));
    _secretKey = key;
    return key;
  }
}

class MemoryDashboardCacheStore implements DashboardCacheStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class MemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
