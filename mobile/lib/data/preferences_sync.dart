import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import 'category_store.dart';
import 'quick_add_shortcut_store.dart';

/// Where the account's copy of the preferences lives.
abstract interface class AccountPreferencesStore {
  /// The signed-in user's id, or null when signed out.
  String? get userId;

  /// The account's copy, fetched fresh from the server. Throws when offline.
  Future<Map<String, dynamic>?> fetch();

  Future<void> save(Map<String, dynamic> preferences);
}

/// Keeps them in the user's Supabase auth metadata: no table is needed, and
/// only that user can read or change it.
class SupabaseAccountPreferencesStore implements AccountPreferencesStore {
  static const metadataKey = 'money_master_preferences';

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    final response = await _auth.getUser();
    final value = response.user?.userMetadata?[metadataKey];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  Future<void> save(Map<String, dynamic> preferences) async {
    // Supabase merges `data` into the existing metadata key by key.
    await _auth.updateUser(UserAttributes(data: {metadataKey: preferences}));
  }
}

/// Keeps custom categories and quick-add shortcuts in the user's account as
/// well as on this phone, so they survive reinstalling the app and follow
/// the account to a new phone. They used to live only on the phone.
///
/// The phone's copy is always written first, so everything works offline;
/// each change is then uploaded, or on the next [pull] if that failed. When
/// both copies changed, the newer one wins, except the first sync after
/// updating the app, which merges the two so nothing is lost.
class PreferencesSync {
  // ignore: prefer_initializing_formals
  PreferencesSync({AccountPreferencesStore? account}) : _account = account;

  /// Uses the Supabase account when the app is configured for it; in tests
  /// and without Supabase keys it only keeps the phone's copy.
  static PreferencesSync instance = PreferencesSync(
    account: AppConfig.hasSupabaseConfig
        ? SupabaseAccountPreferencesStore()
        : null,
  );

  static const _updatedAtKey = 'dmt_preferences_updated_at';
  static const _ownerKey = 'dmt_preferences_owner';
  static const _unsyncedKey = 'dmt_preferences_unsynced';

  final AccountPreferencesStore? _account;

  /// Call after the phone's copy changed.
  Future<void> localChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _updatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await prefs.setBool(_unsyncedKey, true);
    final userId = _account?.userId;
    if (userId != null) await prefs.setString(_ownerKey, userId);
    await _push(prefs);
  }

  /// Brings the phone's copy and the account's copy together. Call when
  /// someone signs in and whenever the app starts signed in.
  Future<void> pull() async {
    final account = _account;
    final userId = account?.userId;
    if (account == null || userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic>? remote;
    try {
      remote = await account.fetch();
    } catch (_) {
      return; // Offline: keep using the phone's copy and try next time.
    }

    final owner = prefs.getString(_ownerKey);
    if (owner != null && owner != userId) {
      // Left behind by someone else who signed in on this phone. Never
      // upload it into this account.
      await _writeLocal(prefs, remote ?? const {});
      await _markSynced(prefs, userId, remote?['updated_at']);
      return;
    }

    final localUpdated = DateTime.tryParse(
      prefs.getString(_updatedAtKey) ?? '',
    );
    final remoteUpdated = DateTime.tryParse(
      remote?['updated_at']?.toString() ?? '',
    );
    final unsynced = prefs.getBool(_unsyncedKey) ?? false;

    if (remote == null || remoteUpdated == null) {
      // Nothing in the account yet: upload what this phone has.
      if (_hasLocal(prefs)) await localChanged();
      await prefs.setString(_ownerKey, userId);
      return;
    }

    if (localUpdated == null) {
      // First sync on this phone since preferences started syncing: keep
      // both copies.
      await _writeLocal(prefs, _merge(_readLocal(prefs), remote));
      await localChanged();
      return;
    }

    if (unsynced && localUpdated.isAfter(remoteUpdated)) {
      await _push(prefs);
      return;
    }

    await _writeLocal(prefs, remote);
    await _markSynced(prefs, userId, remote['updated_at']);
  }

  Future<void> _push(SharedPreferences prefs) async {
    final account = _account;
    if (account == null || account.userId == null) return;
    try {
      await account.save({
        ..._readLocal(prefs),
        'updated_at': prefs.getString(_updatedAtKey),
      });
      await prefs.setBool(_unsyncedKey, false);
    } catch (_) {
      // Stays marked unsynced; the next pull uploads it.
    }
  }

  Future<void> _markSynced(
    SharedPreferences prefs,
    String userId,
    Object? updatedAt,
  ) async {
    await prefs.setString(_ownerKey, userId);
    await prefs.setBool(_unsyncedKey, false);
    if (updatedAt is String) {
      await prefs.setString(_updatedAtKey, updatedAt);
    } else {
      await prefs.remove(_updatedAtKey);
    }
  }

  bool _hasLocal(SharedPreferences prefs) {
    final local = _readLocal(prefs);
    return local.values.any((value) => value is List && value.isNotEmpty);
  }

  Map<String, dynamic> _readLocal(SharedPreferences prefs) {
    List<dynamic> shortcuts;
    try {
      final decoded = jsonDecode(
        prefs.getString(QuickAddShortcutStore.key) ?? '[]',
      );
      shortcuts = decoded is List ? decoded : const [];
    } on FormatException {
      shortcuts = const [];
    }
    return {
      'income_categories':
          prefs.getStringList(CategoryStore.incomeKey) ?? const <String>[],
      'expense_categories':
          prefs.getStringList(CategoryStore.expenseKey) ?? const <String>[],
      'quick_add_shortcuts': shortcuts,
    };
  }

  Future<void> _writeLocal(
    SharedPreferences prefs,
    Map<String, dynamic> preferences,
  ) async {
    await prefs.setStringList(
      CategoryStore.incomeKey,
      _strings(preferences['income_categories']),
    );
    await prefs.setStringList(
      CategoryStore.expenseKey,
      _strings(preferences['expense_categories']),
    );
    final shortcuts = preferences['quick_add_shortcuts'];
    await prefs.setString(
      QuickAddShortcutStore.key,
      jsonEncode(shortcuts is List ? shortcuts : const []),
    );
  }

  Map<String, dynamic> _merge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    List<String> categories(String key) {
      final seen = <String>{};
      return [
        for (final value in [..._strings(remote[key]), ..._strings(local[key])])
          if (seen.add(value.toLowerCase())) value,
      ];
    }

    final shortcutIds = <String>{};
    final shortcuts = [
      for (final list in [
        remote['quick_add_shortcuts'],
        local['quick_add_shortcuts'],
      ])
        if (list is List)
          for (final item in list)
            if (item is Map && shortcutIds.add(item['id'].toString())) item,
    ];
    return {
      'income_categories': categories('income_categories'),
      'expense_categories': categories('expense_categories'),
      'quick_add_shortcuts': shortcuts,
    };
  }

  List<String> _strings(Object? value) {
    return value is List ? value.whereType<String>().toList() : <String>[];
  }
}
