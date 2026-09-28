import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/category_store.dart';

/// Mimi time ("MT" on the dashboard). While it's on, every new expense is
/// saved under the Mimi category, and what it was for is kept at the start
/// of its note ("Food · lunch"), so Mimi's total is right without losing
/// the detail. It stays on, across restarts, until turned off.
///
/// A plain notifier rather than a Riverpod provider so the dashboard and the
/// expense form, which aren't Riverpod consumers, can listen to it.
class MimiTime {
  MimiTime._();

  static final instance = MimiTime._();

  static const _prefsKey = 'dmt_mimi_time';

  /// Between what an expense was for and its note: "Transport · Rickshaw".
  static const _separator = ' · ';

  final ValueNotifier<bool> _enabled = ValueNotifier(false);

  ValueListenable<bool> get enabled => _enabled;

  bool get isOn => _enabled.value;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled.value = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  /// The category and note an expense is saved with during Mimi time.
  static ({String category, String? note}) apply({
    required String category,
    String? note,
  }) {
    final text = note?.trim() ?? '';
    if (category.toLowerCase() == mimiCategory.toLowerCase()) {
      return (category: mimiCategory, note: text.isEmpty ? null : text);
    }
    return (
      category: mimiCategory,
      note: text.isEmpty ? category : '$category$_separator$text',
    );
  }

  /// Splits a Mimi-time note back into what the expense was for and the
  /// note itself, for display: "Transport · Rickshaw" gives Transport and
  /// Rickshaw. A note without the separator is all note.
  static ({String? whatFor, String note}) split(String note) {
    final index = note.indexOf(_separator);
    if (index <= 0) return (whatFor: null, note: note.trim());
    return (
      whatFor: note.substring(0, index).trim(),
      note: note.substring(index + _separator.length).trim(),
    );
  }

  @visibleForTesting
  void reset() => _enabled.value = false;
}
