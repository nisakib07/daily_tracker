import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/cached_money_data_source.dart';
import 'package:money_master/data/category_store.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/features/settings/settings_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RenamingRemote
    implements
        MoneyDataSource,
        IdempotentMoneyMutationExecutor,
        CategoryRenamer {
  final renames = <String>[];

  @override
  Future<DashboardSnapshot> fetchDashboard() async => _snapshot;

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {}

  @override
  Future<void> renameCategory({
    required CategoryKind kind,
    required String from,
    required String to,
  }) async {
    renames.add('${kind.name}: $from -> $to');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _snapshot = DashboardSnapshot(
  accounts: [
    Account(
      id: 'cash',
      name: 'Cash',
      type: 'cash',
      createdAt: DateTime(2026, 1, 1),
    ),
  ],
  people: const [],
  investments: const [],
  transactions: const [],
  budgets: const [],
);

Finder _chip(String category) =>
    find.byKey(ValueKey('settings-expense-chip-$category'));

Future<_RenamingRemote> _pumpSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final remote = _RenamingRemote();
  final cache = CachedMoneyDataSource(
    remote,
    cacheKey: 'user-1',
    staleAfter: const Duration(days: 1),
    cacheStore: MemoryDashboardCacheStore(),
  );
  addTearDown(cache.close);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SettingsSheet(
          email: 'me@example.com',
          userId: 'user-1',
          dataSource: cache,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _scrollTo(tester, _chip('Food'));
  return remote;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('settings-scroll-view')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _renameFood(WidgetTester tester, String to) async {
  await tester.tap(_chip('Food'));
  await tester.pumpAndSettle();
  expect(find.text('Rename category'), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('rename-category-input')),
    to,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renaming updates saved transactions, then the list', (
    tester,
  ) async {
    final remote = await _pumpSettings(tester);

    await _renameFood(tester, 'Meals');

    expect(remote.renames, ['expense: Food -> Meals']);
    expect(_chip('Food'), findsNothing);
    expect(_chip('Meals'), findsOneWidget);
    expect(
      find.textContaining('including saved transactions and budgets'),
      findsOneWidget,
    );
    expect(
      await CategoryStore().loadMerged(CategoryKind.expense),
      contains('Meals'),
    );
  });

  testWidgets('a name already in use is refused', (tester) async {
    final remote = await _pumpSettings(tester);

    await _renameFood(tester, 'transport');

    expect(find.text('That category already exists.'), findsOneWidget);
    expect(remote.renames, isEmpty);
  });

  testWidgets('a removed built-in can be restored', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(
      find.descendant(of: _chip('Food'), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('keep it'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Category'));
    await tester.pumpAndSettle();
    expect(_chip('Food'), findsNothing);

    final restore = find.byKey(const ValueKey('settings-expense-restore'));
    await _scrollTo(tester, restore);
    expect(find.text('Restore 1 removed default'), findsOneWidget);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(_chip('Food'), findsOneWidget);
    expect(restore, findsNothing);
  });

  testWidgets('Mimi cannot be renamed or removed', (tester) async {
    await _pumpSettings(tester);
    await _scrollTo(tester, _chip('Mimi'));

    expect(
      find.descendant(of: _chip('Mimi'), matching: find.byIcon(Icons.close)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _chip('Mimi'),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    await tester.tap(_chip('Mimi'));
    await tester.pumpAndSettle();
    expect(find.text('Rename category'), findsNothing);
  });
}
