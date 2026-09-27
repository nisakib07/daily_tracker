import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/cached_money_data_source.dart';
import 'package:money_master/data/data_export.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/features/settings/settings_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _created = DateTime(2026, 1, 1);

final _snapshot = DashboardSnapshot(
  accounts: [
    Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: _created),
    Account(id: 'bkash', name: 'bKash', type: 'wallet', createdAt: _created),
  ],
  people: [Person(id: 'rahim', name: 'Rahim', createdAt: _created)],
  investments: [
    Investment(
      id: 'bond',
      name: 'Savings bond',
      status: 'active',
      createdAt: _created,
    ),
  ],
  budgets: [
    Budget(
      id: 'budget-1',
      month: DateTime(2026, 9),
      category: 'Food',
      amount: 5000,
      createdAt: _created,
      updatedAt: _created,
    ),
  ],
  transactions: [
    TransactionRecord(
      id: 'tx-1',
      type: 'expense',
      amount: 18.5,
      fromAccountId: 'bkash',
      category: 'Fees',
      note: 'Cash out, "urgent"\nsecond line',
      occurredAt: DateTime(2026, 9, 14, 9, 5),
      createdAt: DateTime(2026, 9, 14, 9, 5),
    ),
    TransactionRecord(
      id: 'tx-2',
      type: 'lend',
      amount: 1000,
      fromAccountId: 'cash',
      personId: 'rahim',
      category: 'Loan Given',
      note: '=HYPERLINK("x")',
      occurredAt: DateTime(2026, 9, 10, 18, 30),
      createdAt: DateTime(2026, 9, 10, 18, 30),
    ),
    TransactionRecord(
      id: 'tx-3',
      type: 'invest',
      amount: 2500,
      fromAccountId: 'cash',
      investmentId: 'bond',
      category: 'Investment',
      occurredAt: DateTime(2026, 9, 1, 12),
      createdAt: DateTime(2026, 9, 1, 12),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('CSV has readable names, plain amounts and safe fields', () {
    final csv = transactionsCsv(_snapshot);

    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).split('\r\n');
    expect(
      lines.first,
      'Date,Time,Type,Amount,Category,From Account,To Account,Person,'
      'Investment,Note',
    );
    // Quotes, commas and line breaks stay inside one quoted field.
    expect(
      lines[1],
      '2026-09-14,09:05,Expense,18.50,Fees,bKash,,,,'
      '"Cash out, ""urgent""\nsecond line"',
    );
    // Text that looks like a formula can't run in a spreadsheet.
    expect(
      lines[2],
      '2026-09-10,18:30,Loan given,1000.00,Loan Given,Cash,,Rahim,,'
      '"\'=HYPERLINK(""x"")"',
    );
    expect(
      lines[3],
      '2026-09-01,12:00,Investment,2500.00,Investment,Cash,,,'
      'Savings bond,',
    );
    expect(lines.last, isEmpty);
  });

  test('backup matches the website format and can be imported there', () {
    final json =
        jsonDecode(
              backupJson(
                _snapshot,
                userId: 'user-1',
                exportedAt: DateTime.utc(2026, 9, 27, 10),
                customIncomeCategories: const ['Tuition'],
                customExpenseCategories: const ['Fees'],
              ),
            )
            as Map<String, dynamic>;

    expect(json['version'], 1);
    expect(json['exportedAt'], '2026-09-27T10:00:00.000Z');
    final data = json['data'] as Map<String, dynamic>;
    for (final table in [
      'accounts',
      'people',
      'investments',
      'transactions',
      'budgets',
    ]) {
      final rows = (data[table] as List).cast<Map<String, dynamic>>();
      expect(rows, isNotEmpty, reason: table);
      // The website's import writes rows back as they are; row-level
      // security only accepts ones owned by the signed-in user.
      expect(rows.every((row) => row['user_id'] == 'user-1'), isTrue);
    }
    final transaction = (data['transactions'] as List).first as Map;
    expect(transaction['id'], 'tx-1');
    expect(transaction['amount'], 18.5);
    expect(transaction['from_account_id'], 'bkash');
    expect(transaction['occurred_at'], endsWith('Z'));
    expect(transaction.containsKey('date'), isFalse);
    expect((data['budgets'] as List).first['month'], '2026-09-01');
    expect(data['customCategories'], {
      'income': ['Tuition'],
      'expense': ['Fees'],
    });
  });

  testWidgets('Settings exports a CSV through the share sheet', (tester) async {
    final shared = <ExportFile>[];
    final setup = await _pumpSettings(tester, shared);

    await _tapExport(tester, 'settings-export-csv');

    final file = shared.single;
    expect(file.name, startsWith('money-master-transactions-'));
    expect(file.name, endsWith('.csv'));
    expect(file.mimeType, 'text/csv');
    final csv = file.contents;
    expect(csv, contains('Expense,18.50,Fees,bKash'));
    await setup.close();
  });

  testWidgets('Settings backup includes the custom categories', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dmt_custom_expense_categories': <String>['Fees'],
    });
    final shared = <ExportFile>[];
    final setup = await _pumpSettings(tester, shared);

    await _tapExport(tester, 'settings-export-backup');

    final file = shared.single;
    expect(file.name, startsWith('money-master-backup-'));
    final json = jsonDecode(file.contents) as Map;
    final data = json['data'] as Map;
    expect((data['transactions'] as List), hasLength(3));
    expect(data['customCategories']['expense'], ['Fees']);
    await setup.close();
  });

  testWidgets('offline, it exports the last synced data and says so', (
    tester,
  ) async {
    final shared = <ExportFile>[];
    final setup = await _pumpSettings(tester, shared);
    await setup.fetchDashboard();
    (setup.remote as _FakeRemote).offline = true;

    await _tapExport(tester, 'settings-export-csv');

    expect(shared, hasLength(1));
    expect(find.textContaining("You're offline"), findsOneWidget);
    await setup.close();
  });
}

Future<CachedMoneyDataSource> _pumpSettings(
  WidgetTester tester,
  List<ExportFile> shared,
) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final cache = CachedMoneyDataSource(
    _FakeRemote(),
    cacheKey: 'user-1',
    staleAfter: const Duration(days: 1),
    cacheStore: MemoryDashboardCacheStore(),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SettingsSheet(
          email: 'me@example.com',
          userId: 'user-1',
          exportSource: cache,
          shareFile: (file, subject) async => shared.add(file),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

Future<void> _tapExport(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('settings-scroll-view')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _FakeRemote implements MoneyDataSource, IdempotentMoneyMutationExecutor {
  bool offline = false;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    if (offline) throw TimeoutException('offline');
    return _snapshot;
  }

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
