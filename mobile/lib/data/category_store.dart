import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_sync.dart';

const defaultIncomeCategories = [
  'Salary',
  'Freelance',
  'Gift',
  'Investment Return',
  'Business',
  'Other Income',
];

const defaultExpenseCategories = [
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Entertainment',
  'Health',
  'Education',
  'Rent',
  'Charity',
  'Personal_Care',
  'Other Expense',
];

enum CategoryKind { income, expense }

/// Custom categories, kept on the phone and synced to the account by
/// [PreferencesSync].
class CategoryStore {
  static const incomeKey = 'dmt_custom_income_categories';
  static const expenseKey = 'dmt_custom_expense_categories';

  Future<List<String>> loadCustom(CategoryKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFor(kind)) ?? const [];
  }

  Future<List<String>> loadMerged(CategoryKind kind) async {
    final defaults = switch (kind) {
      CategoryKind.income => defaultIncomeCategories,
      CategoryKind.expense => defaultExpenseCategories,
    };
    final custom = await loadCustom(kind);
    return _unique([...defaults, ...custom]);
  }

  Future<void> addCustom(CategoryKind kind, String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final custom = await loadCustom(kind);
    final updated = _unique([...custom, trimmed]);
    await prefs.setStringList(_keyFor(kind), updated);
    await PreferencesSync.instance.localChanged();
  }

  Future<void> deleteCustom(CategoryKind kind, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = await loadCustom(kind);
    final updated = custom.where((item) => item != category).toList();
    await prefs.setStringList(_keyFor(kind), updated);
    await PreferencesSync.instance.localChanged();
  }

  String _keyFor(CategoryKind kind) {
    return switch (kind) {
      CategoryKind.income => incomeKey,
      CategoryKind.expense => expenseKey,
    };
  }
}

List<String> _unique(List<String> values) {
  final seen = <String>{};
  final result = <String>[];

  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) result.add(trimmed);
  }

  return result;
}
