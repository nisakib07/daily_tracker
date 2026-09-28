import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/category_store.dart';
import 'package:money_master/data/preferences_sync.dart';
import 'package:money_master/data/quick_add_shortcut_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccount implements AccountPreferencesStore {
  _FakeAccount({this.stored});

  Map<String, dynamic>? stored;
  final saves = <Map<String, dynamic>>[];
  bool offline = false;

  @override
  String? userId = 'me';

  @override
  Future<Map<String, dynamic>?> fetch() async {
    if (offline) throw Exception('offline');
    return stored;
  }

  @override
  Future<void> save(Map<String, dynamic> preferences) async {
    if (offline) throw Exception('offline');
    saves.add(preferences);
    stored = preferences;
  }
}

const _shortcut = {
  'id': 'lunch',
  'category': 'Food',
  'subCategory': 'Lunch',
  'accountId': 'cash',
  'amount': 120,
};

Future<List<String>> _custom(CategoryKind kind) {
  return CategoryStore().loadCustom(kind);
}

void main() {
  late PreferencesSync original;
  setUp(() => original = PreferencesSync.instance);
  tearDown(() => PreferencesSync.instance = original);

  _FakeAccount use(_FakeAccount account) {
    PreferencesSync.instance = PreferencesSync(account: account);
    return account;
  }

  test(
    'a new phone takes the categories and shortcuts from the account',
    () async {
      SharedPreferences.setMockInitialValues({});
      use(
        _FakeAccount(
          stored: {
            'income_categories': ['Tuition'],
            'expense_categories': ['Fees'],
            'quick_add_shortcuts': [_shortcut],
            'updated_at': '2026-09-20T10:00:00.000Z',
          },
        ),
      );

      await PreferencesSync.instance.pull();

      expect(await _custom(CategoryKind.income), ['Tuition']);
      expect(await _custom(CategoryKind.expense), ['Fees']);
      final shortcuts = await QuickAddShortcutStore().load();
      expect(shortcuts.single.subCategory, 'Lunch');
      expect(shortcuts.single.amount, 120);
    },
  );

  test('an empty account gets what this phone already has', () async {
    SharedPreferences.setMockInitialValues({
      CategoryStore.expenseKey: <String>['Fees'],
    });
    final account = use(_FakeAccount());

    await PreferencesSync.instance.pull();

    expect(account.saves.single['expense_categories'], ['Fees']);
    expect(account.saves.single['updated_at'], isNotNull);
  });

  test('the first sync merges both copies so nothing is lost', () async {
    SharedPreferences.setMockInitialValues({
      CategoryStore.expenseKey: <String>['Fees', 'Rickshaw'],
    });
    final account = use(
      _FakeAccount(
        stored: {
          'income_categories': <String>[],
          'expense_categories': ['Rickshaw', 'Tea'],
          'quick_add_shortcuts': <Object>[],
          'updated_at': '2026-09-20T10:00:00.000Z',
        },
      ),
    );

    await PreferencesSync.instance.pull();

    expect(await _custom(CategoryKind.expense), ['Rickshaw', 'Tea', 'Fees']);
    expect(account.stored!['expense_categories'], ['Rickshaw', 'Tea', 'Fees']);
  });

  test('removed built-in categories sync both ways', () async {
    SharedPreferences.setMockInitialValues({});
    final account = use(_FakeAccount());

    await CategoryStore().deleteCategory(CategoryKind.expense, 'Food');
    expect(account.stored!['hidden_expense_categories'], ['Food']);

    // Another phone restored it and removed Transport instead.
    account.stored = {
      ...account.stored!,
      'hidden_expense_categories': ['Transport'],
      'updated_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    await PreferencesSync.instance.pull();

    final list = await CategoryStore().loadMerged(CategoryKind.expense);
    expect(list, contains('Food'));
    expect(list, isNot(contains('Transport')));
  });

  test('a change is uploaded as soon as it is made', () async {
    SharedPreferences.setMockInitialValues({});
    final account = use(_FakeAccount());

    await CategoryStore().addCustom(CategoryKind.expense, 'Fees');
    await QuickAddShortcutStore().add(
      QuickAddShortcut.fromJson(Map<String, dynamic>.from(_shortcut))!,
    );

    expect(account.stored!['expense_categories'], ['Fees']);
    expect((account.stored!['quick_add_shortcuts'] as List).single, isA<Map>());
  });

  test('a change made offline is uploaded on the next sync', () async {
    SharedPreferences.setMockInitialValues({});
    final account = use(
      _FakeAccount(
        stored: {
          'expense_categories': <String>[],
          'updated_at': '2020-01-01T00:00:00.000Z',
        },
      ),
    )..offline = true;

    await CategoryStore().addCustom(CategoryKind.expense, 'Fees');
    expect(account.saves, isEmpty);

    account.offline = false;
    await PreferencesSync.instance.pull();

    expect(account.stored!['expense_categories'], ['Fees']);
    expect(await _custom(CategoryKind.expense), ['Fees']);
  });

  test('a newer copy from another phone replaces a synced one', () async {
    SharedPreferences.setMockInitialValues({});
    final account = use(_FakeAccount());
    await CategoryStore().addCustom(CategoryKind.expense, 'Fees');

    account.stored = {
      'income_categories': <String>[],
      'expense_categories': ['Fees', 'Tea'],
      'quick_add_shortcuts': <Object>[],
      'updated_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    await PreferencesSync.instance.pull();

    expect(await _custom(CategoryKind.expense), ['Fees', 'Tea']);
  });

  test("someone else's leftovers on this phone are never uploaded", () async {
    SharedPreferences.setMockInitialValues({
      CategoryStore.expenseKey: <String>['Private'],
      'dmt_preferences_owner': 'someone-else',
      'dmt_preferences_updated_at': '2026-09-20T10:00:00.000Z',
      'dmt_preferences_unsynced': true,
    });
    final account = use(_FakeAccount());

    await PreferencesSync.instance.pull();

    expect(account.saves, isEmpty);
    expect(await _custom(CategoryKind.expense), isEmpty);
  });

  test('offline or signed out, pull leaves the phone copy alone', () async {
    SharedPreferences.setMockInitialValues({
      CategoryStore.expenseKey: <String>['Fees'],
    });
    final account = use(_FakeAccount()..offline = true);
    await PreferencesSync.instance.pull();
    account
      ..offline = false
      ..userId = null;
    await PreferencesSync.instance.pull();

    expect(account.saves, isEmpty);
    expect(await _custom(CategoryKind.expense), ['Fees']);
  });
}
