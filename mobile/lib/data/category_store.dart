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

/// Where expenses go during Mimi time (see MimiTime).
const mimiCategory = 'Mimi';

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
  mimiCategory,
  'Other Expense',
];

enum CategoryKind { income, expense }

/// The categories offered in forms: the built-in ones, minus any the user
/// removed, plus the user's own. Kept on the phone and synced to the account
/// by [PreferencesSync]. Removing a built-in only hides it, so it can be
/// restored; renaming one hides it and adds the new name as the user's own.
/// Mimi can't be removed or renamed, since Mimi time depends on it.
class CategoryStore {
  static const incomeKey = 'dmt_custom_income_categories';
  static const expenseKey = 'dmt_custom_expense_categories';
  static const hiddenIncomeKey = 'dmt_hidden_income_categories';
  static const hiddenExpenseKey = 'dmt_hidden_expense_categories';

  static List<String> defaultsFor(CategoryKind kind) {
    return switch (kind) {
      CategoryKind.income => defaultIncomeCategories,
      CategoryKind.expense => defaultExpenseCategories,
    };
  }

  /// Whether [category] can't be renamed or removed.
  static bool isLocked(String category) => _same(category, mimiCategory);

  /// The user's own categories.
  Future<List<String>> loadCustom(CategoryKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFor(kind)) ?? const [];
  }

  /// Built-in categories the user removed.
  Future<List<String>> loadHidden(CategoryKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenKeyFor(kind)) ?? const [];
  }

  Future<List<String>> loadMerged(CategoryKind kind) async {
    final hidden = await loadHidden(kind);
    final custom = await loadCustom(kind);
    return _unique([
      for (final category in defaultsFor(kind))
        if (!hidden.any((item) => _same(item, category))) category,
      ...custom,
    ]);
  }

  Future<void> addCustom(CategoryKind kind, String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final hidden = await loadHidden(kind);
    if (hidden.any((item) => _same(item, trimmed))) {
      // Adding back a removed built-in just shows it again.
      await prefs.setStringList(
        _hiddenKeyFor(kind),
        hidden.where((item) => !_same(item, trimmed)).toList(),
      );
    } else {
      final custom = await loadCustom(kind);
      await prefs.setStringList(_keyFor(kind), _unique([...custom, trimmed]));
    }
    await PreferencesSync.instance.localChanged();
  }

  /// Removes [category] from the list. Transactions already saved with it
  /// keep it.
  Future<void> deleteCategory(CategoryKind kind, String category) async {
    if (isLocked(category)) {
      throw ArgumentError.value(category, 'category', 'cannot be removed');
    }
    final prefs = await SharedPreferences.getInstance();
    await _removeLocally(prefs, kind, category);
    await PreferencesSync.instance.localChanged();
  }

  /// Renames [from] to [to] in the list. Renaming it on saved transactions
  /// and budgets is done separately, on the server.
  Future<void> renameCategory(CategoryKind kind, String from, String to) async {
    final trimmed = to.trim();
    if (isLocked(from)) {
      throw ArgumentError.value(from, 'from', 'cannot be renamed');
    }
    if (trimmed.isEmpty || trimmed == from) return;

    final prefs = await SharedPreferences.getInstance();
    final custom = await loadCustom(kind);
    final index = custom.indexWhere((item) => _same(item, from));
    if (index != -1) {
      // The user's own category keeps its place in the list.
      final updated = [...custom]..[index] = trimmed;
      await prefs.setStringList(_keyFor(kind), _unique(updated));
    } else {
      await _removeLocally(prefs, kind, from);
      final hidden = await loadHidden(kind);
      if (hidden.any((item) => _same(item, trimmed))) {
        await prefs.setStringList(
          _hiddenKeyFor(kind),
          hidden.where((item) => !_same(item, trimmed)).toList(),
        );
      } else {
        final current = await loadCustom(kind);
        await prefs.setStringList(
          _keyFor(kind),
          _unique([...current, trimmed]),
        );
      }
    }
    await PreferencesSync.instance.localChanged();
  }

  /// Shows every built-in category again.
  Future<void> restoreDefaults(CategoryKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenKeyFor(kind), const []);
    await PreferencesSync.instance.localChanged();
  }

  Future<void> _removeLocally(
    SharedPreferences prefs,
    CategoryKind kind,
    String category,
  ) async {
    if (defaultsFor(kind).any((item) => _same(item, category))) {
      final hidden = await loadHidden(kind);
      await prefs.setStringList(
        _hiddenKeyFor(kind),
        _unique([...hidden, category]),
      );
    }
    final custom = await loadCustom(kind);
    await prefs.setStringList(
      _keyFor(kind),
      custom.where((item) => !_same(item, category)).toList(),
    );
  }

  String _keyFor(CategoryKind kind) {
    return switch (kind) {
      CategoryKind.income => incomeKey,
      CategoryKind.expense => expenseKey,
    };
  }

  String _hiddenKeyFor(CategoryKind kind) {
    return switch (kind) {
      CategoryKind.income => hiddenIncomeKey,
      CategoryKind.expense => hiddenExpenseKey,
    };
  }
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

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
