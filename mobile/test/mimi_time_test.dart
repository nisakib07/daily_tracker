import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/mimi_time.dart';
import 'package:money_master/data/category_store.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/dashboard/dashboard_screen.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MimiTime.instance.reset();
  });
  tearDown(MimiTime.instance.reset);

  test('Mimi is one of the expense categories', () {
    expect(defaultExpenseCategories, contains('Mimi'));
  });

  test('keeps what an expense was for at the start of its note', () {
    expect(MimiTime.apply(category: 'Food', note: ' lunch '), (
      category: 'Mimi',
      note: 'Food · lunch',
    ));
    expect(MimiTime.apply(category: 'Transport', note: ''), (
      category: 'Mimi',
      note: 'Transport',
    ));
    // Choosing Mimi itself doesn't repeat it in the note.
    expect(MimiTime.apply(category: 'mimi', note: 'movie'), (
      category: 'Mimi',
      note: 'movie',
    ));
  });

  test('stays on across restarts until turned off', () async {
    await MimiTime.instance.setEnabled(true);
    MimiTime.instance.reset();
    await MimiTime.instance.load();
    expect(MimiTime.instance.isOn, isTrue);

    await MimiTime.instance.setEnabled(false);
    await MimiTime.instance.load();
    expect(MimiTime.instance.isOn, isFalse);
  });

  testWidgets('during Mimi time an expense is saved under Mimi', (
    tester,
  ) async {
    await MimiTime.instance.setEnabled(true);
    final recorded = await _saveExpense(tester, note: 'lunch');

    expect(recorded, [('expense', 'Mimi', 'Food · lunch')]);
  });

  testWidgets('the form says so and asks what it was for', (tester) async {
    await MimiTime.instance.setEnabled(true);
    await _pumpForm(tester, TransactionEntryKind.expense, _Recorder());

    expect(find.byKey(const ValueKey('mimi-time-notice')), findsOneWidget);
    expect(find.text('What for'), findsOneWidget);
  });

  testWidgets('outside Mimi time expenses keep their category', (tester) async {
    final recorded = await _saveExpense(tester, note: 'lunch');

    expect(recorded, [('expense', 'Food', 'lunch')]);
    expect(find.byKey(const ValueKey('mimi-time-notice')), findsNothing);
  });

  testWidgets('income is never moved to Mimi', (tester) async {
    await MimiTime.instance.setEnabled(true);
    final recorder = _Recorder();
    await _pumpForm(tester, TransactionEntryKind.income, recorder);

    expect(find.byKey(const ValueKey('mimi-time-notice')), findsNothing);
    await _fillAndSave(tester, 'Add Income', note: 'September');
    expect(recorder.saved, [('income', 'Salary', 'September')]);
  });

  testWidgets('the dashboard MT box turns Mimi time on and off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: DashboardScreen(
          user: _user,
          snapshotLoader: () async => _snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('mimi-time-toggle'));
    expect(find.text('MT'), findsOneWidget);
    expect(find.text('Mimi time'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      find.text('Mimi time is on: new expenses go to Mimi'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dmt_mimi_time'), isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Mimi time'), findsOneWidget);
    expect(prefs.getBool('dmt_mimi_time'), isFalse);
  });
}

Future<List<(String, String, String?)>> _saveExpense(
  WidgetTester tester, {
  required String note,
}) async {
  final recorder = _Recorder();
  await _pumpForm(tester, TransactionEntryKind.expense, recorder);
  await _fillAndSave(tester, 'Add Expense', note: note);
  return recorder.saved;
}

Future<void> _pumpForm(
  WidgetTester tester,
  TransactionEntryKind kind,
  MoneyDataSource dataSource,
) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: TransactionEntrySheet(
        kind: kind,
        accounts: [AccountBalance(account: _cash, balance: 5000)],
        dataSource: dataSource,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSave(
  WidgetTester tester,
  String saveLabel, {
  required String note,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '120');
  await tester.enterText(find.widgetWithText(TextFormField, 'Note'), note);
  final save = find.widgetWithText(FilledButton, saveLabel);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

class _Recorder implements MoneyDataSource {
  final saved = <(String, String, String?)>[];

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    saved.add(('expense', category, note));
  }

  @override
  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    saved.add(('income', category, note));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _created = DateTime(2026, 1, 1);
final _cash = Account(
  id: 'cash',
  name: 'Cash',
  type: 'cash',
  createdAt: _created,
);

final _snapshot = DashboardSnapshot(
  accounts: [_cash],
  people: const [],
  investments: const [],
  transactions: const [],
  budgets: const [],
);

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'me@example.com',
  createdAt: '2026-07-10T00:00:00.000Z',
);
