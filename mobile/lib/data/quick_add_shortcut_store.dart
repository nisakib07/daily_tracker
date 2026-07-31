import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A user-defined quick-add shortcut for the expense entry form. Selecting
/// one fills the category, note (from [subCategory]), account, and
/// optionally the amount in a single tap - replacing the old hardcoded
/// breakfast/lunch/dinner list with something each user configures in
/// Settings.
class QuickAddShortcut {
  const QuickAddShortcut({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.accountId,
    this.amount,
  });

  final String id;
  final String category;
  final String subCategory;
  final String accountId;
  final double? amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'subCategory': subCategory,
    'accountId': accountId,
    if (amount != null) 'amount': amount,
  };

  static QuickAddShortcut? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final category = json['category'];
    final subCategory = json['subCategory'];
    final accountId = json['accountId'];
    if (id is! String || category is! String || subCategory is! String) {
      return null;
    }
    if (accountId is! String) return null;

    final amount = json['amount'];
    return QuickAddShortcut(
      id: id,
      category: category,
      subCategory: subCategory,
      accountId: accountId,
      amount: amount is num ? amount.toDouble() : null,
    );
  }
}

class QuickAddShortcutStore {
  static const _key = 'dmt_quick_add_shortcuts';

  Future<List<QuickAddShortcut>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                QuickAddShortcut.fromJson(Map<String, dynamic>.from(item)),
          )
          .whereType<QuickAddShortcut>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> add(QuickAddShortcut shortcut) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final updated = [...current, shortcut];
    await prefs.setString(
      _key,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final updated = current.where((item) => item.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> update(QuickAddShortcut shortcut) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final updated = [
      for (final item in current)
        if (item.id == shortcut.id) shortcut else item,
    ];
    await prefs.setString(
      _key,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }
}
