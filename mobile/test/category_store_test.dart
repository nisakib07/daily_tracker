import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/category_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CategoryStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = CategoryStore();
  });

  Future<List<String>> expense() => store.loadMerged(CategoryKind.expense);

  test('lists the built-in categories, then your own', () async {
    await store.addCustom(CategoryKind.expense, 'Tea');

    final list = await expense();
    expect(list.first, 'Food');
    expect(list, contains('Mimi'));
    expect(list.last, 'Tea');
  });

  test('removing a built-in hides it, and adding it back shows it', () async {
    await store.deleteCategory(CategoryKind.expense, 'Food');
    expect(await expense(), isNot(contains('Food')));
    expect(await store.loadHidden(CategoryKind.expense), ['Food']);

    await store.addCustom(CategoryKind.expense, 'food');
    expect((await expense()).first, 'Food');
    expect(await store.loadCustom(CategoryKind.expense), isEmpty);
  });

  test('renaming a built-in replaces it with the new name', () async {
    await store.renameCategory(CategoryKind.expense, 'Food', 'Meals');

    final list = await expense();
    expect(list, isNot(contains('Food')));
    expect(list, contains('Meals'));
  });

  test('renaming your own category keeps its place', () async {
    await store.addCustom(CategoryKind.income, 'Tuition');
    await store.addCustom(CategoryKind.income, 'Rent in');

    await store.renameCategory(CategoryKind.income, 'Tuition', 'Coaching');

    expect(await store.loadCustom(CategoryKind.income), [
      'Coaching',
      'Rent in',
    ]);
  });

  test('removing your own category drops it', () async {
    await store.addCustom(CategoryKind.expense, 'Tea');
    await store.deleteCategory(CategoryKind.expense, 'Tea');

    expect(await expense(), isNot(contains('Tea')));
    expect(await store.loadHidden(CategoryKind.expense), isEmpty);
  });

  test('restoring defaults brings back every built-in', () async {
    await store.deleteCategory(CategoryKind.expense, 'Food');
    await store.renameCategory(CategoryKind.expense, 'Transport', 'Travel');

    await store.restoreDefaults(CategoryKind.expense);

    final list = await expense();
    expect(list, containsAll(['Food', 'Transport', 'Travel']));
  });

  test('Mimi cannot be removed or renamed', () async {
    expect(CategoryStore.isLocked('mimi'), isTrue);
    expect(
      () => store.deleteCategory(CategoryKind.expense, 'Mimi'),
      throwsArgumentError,
    );
    expect(
      () => store.renameCategory(CategoryKind.expense, 'Mimi', 'Us'),
      throwsArgumentError,
    );
    expect(await expense(), contains('Mimi'));
  });
}
