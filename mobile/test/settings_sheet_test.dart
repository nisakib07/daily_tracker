import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/settings/settings_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _incomeKey = 'dmt_custom_income_categories';
const _expenseKey = 'dmt_custom_expense_categories';
const _quickAddKey = 'dmt_quick_add_shortcuts';
const _longCategory =
    'A consulting and professional services category with an exceptionally long display name';

final _testAccountCreatedAt = DateTime(2026, 1, 1);
final _testCashAccount = Account(
  id: 'cash-1',
  name: 'Cash',
  type: 'cash',
  createdAt: _testAccountCreatedAt,
);
final _testAccounts = [
  AccountBalance(account: _testCashAccount, balance: 1000),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Settings fits a narrow phone with long saved values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _incomeKey: <String>[_longCategory],
      _expenseKey: <String>[],
    });

    await _pumpAtSize(
      tester,
      const Size(320, 568),
      const SettingsSheet(
        email: 'a.very.long.account.email.address@example-company.com',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Personal categories'), findsOneWidget);

    await _scrollToCategories(tester, find.text('Income Categories'));
    expect(find.text('Income Categories'), findsOneWidget);
    expect(find.text('Expense Categories'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-income-chip-$_longCategory')),
      findsOneWidget,
    );
    expect(find.text('No custom expense categories yet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('settings-scroll-view')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings reports duplicate categories without saving again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _incomeKey: <String>['Consulting'],
    });

    await _pumpAtSize(
      tester,
      const Size(320, 568),
      const SettingsSheet(email: 'user@example.com'),
    );
    await tester.pumpAndSettle();

    final incomeInput = find.byKey(const ValueKey('settings-income-input'));
    await _scrollToCategories(tester, incomeInput);
    await tester.enterText(incomeInput, 'consulting');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('This category already exists.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_incomeKey), ['Consulting']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings adds and deletes persisted categories', (tester) async {
    SharedPreferences.setMockInitialValues({
      _incomeKey: <String>['Consulting'],
      _expenseKey: <String>[],
    });

    await _pumpAtSize(
      tester,
      const Size(320, 568),
      const SettingsSheet(email: 'user@example.com'),
    );
    await tester.pumpAndSettle();

    final expenseInput = find.byKey(const ValueKey('settings-expense-input'));
    await _scrollToCategories(tester, expenseInput);
    await tester.enterText(expenseInput, 'Home repairs');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_expenseKey), ['Home repairs']);
    expect(
      find.byKey(const ValueKey('settings-expense-chip-Home repairs')),
      findsOneWidget,
    );

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final consultingChip = find.byKey(
      const ValueKey('settings-income-chip-Consulting'),
    );
    await tester.tap(
      find.descendant(of: consultingChip, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete Category?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete Category'));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_incomeKey), isEmpty);
    expect(consultingChip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings pairs category panels on wide desktop', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(1440, 900),
      const SettingsSheet(email: 'user@example.com'),
    );
    await tester.pumpAndSettle();

    final workspaceSize = tester.getSize(
      find.byKey(const ValueKey('settings-workspace')),
    );
    final incomeTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('settings-income-section')),
    );
    final expenseTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('settings-expense-section')),
    );

    expect(workspaceSize.width, lessThanOrEqualTo(920));
    expect(expenseTopLeft.dx, greaterThan(incomeTopLeft.dx));
    expect(expenseTopLeft.dy, closeTo(incomeTopLeft.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings appearance toggle switches and persists theme mode', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      const SettingsSheet(email: 'user@example.com'),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('settings-theme-mode-toggle'));
    expect(toggle, findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<ThemeMode>>(toggle);
    expect(segmentedButton.selected, {ThemeMode.light});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dmt_theme_mode'), 'light');
    expect(tester.takeException(), isNull);
  });

  // local_auth.isDeviceSupported() never resolves without a registered
  // platform channel in the widget test harness (it hangs rather than
  // throwing), so this can only be exercised on-device.
  testWidgets(
    'Settings shows app lock as unavailable when the device has no screen lock',
    skip: true,
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 568),
        const SettingsSheet(email: 'user@example.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security & Reminders'), findsOneWidget);
      expect(
        find.text(
          'No screen lock is set up on this device, so this is unavailable',
        ),
        findsOneWidget,
      );

      final lockSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('settings-app-lock-toggle')),
      );
      expect(lockSwitch.value, isFalse);
      expect(lockSwitch.onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  // FlutterTimezone.getLocalTimezone() never resolves without a registered
  // platform channel in the widget test harness (it hangs rather than
  // throwing), so this can only be exercised on-device.
  testWidgets(
    'Settings daily reminder toggle fails gracefully without the native plugin',
    skip: true,
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 568),
        const SettingsSheet(email: 'user@example.com'),
      );
      await tester.pumpAndSettle();

      final reminderSwitch = find.byKey(
        const ValueKey('settings-daily-reminder-toggle'),
      );
      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);

      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();

      // No native notification plugin is registered in the widget test
      // environment, so enabling should fail gracefully with a message
      // rather than throwing or silently reporting success.
      expect(
        find.textContaining('Notification permission was denied'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings shows a notice when there are no accounts for quick add shortcuts',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 568),
        const SettingsSheet(email: 'user@example.com'),
      );
      await tester.pumpAndSettle();

      await _scrollToCategories(tester, find.text('Quick Add Shortcuts'));
      expect(
        find.text('Add an account first to create quick add shortcuts.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Settings adds and deletes a quick add shortcut', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      SettingsSheet(email: 'user@example.com', accounts: _testAccounts),
    );
    await tester.pumpAndSettle();

    final subCategoryInput = find.byKey(
      const ValueKey('settings-quick-add-subcategory-input'),
    );
    await _scrollToCategories(tester, subCategoryInput);
    await tester.enterText(subCategoryInput, 'Rickshaw');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-quick-add-submit')));
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    var saved = jsonDecode(prefs.getString(_quickAddKey) ?? '[]') as List;
    expect(saved, hasLength(1));
    expect(saved.single['subCategory'], 'Rickshaw');
    expect(saved.single['accountId'], _testCashAccount.id);

    final itemId = saved.single['id'] as String;
    expect(
      find.byKey(ValueKey('settings-quick-add-item-$itemId')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('settings-quick-add-delete-$itemId')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Quick Add?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete Quick Add'));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    saved = jsonDecode(prefs.getString(_quickAddKey) ?? '[]') as List;
    expect(saved, isEmpty);
    expect(
      find.byKey(ValueKey('settings-quick-add-item-$itemId')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings edits an existing quick add shortcut in place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _quickAddKey: jsonEncode([
        {
          'id': 'qa-edit',
          'category': 'Food',
          'subCategory': 'Lunch',
          'accountId': _testCashAccount.id,
          'amount': 100,
        },
      ]),
    });

    await _pumpAtSize(
      tester,
      const Size(320, 568),
      SettingsSheet(email: 'user@example.com', accounts: _testAccounts),
    );
    await tester.pumpAndSettle();

    final scrollView = find.byKey(const ValueKey('settings-scroll-view'));
    final editButton = find.byKey(
      const ValueKey('settings-quick-add-edit-qa-edit'),
    );
    for (var i = 0; i < 8; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    final subCategoryInput = find.byKey(
      const ValueKey('settings-quick-add-subcategory-input'),
    );
    expect(
      tester.widget<TextField>(subCategoryInput).controller?.text,
      'Lunch',
    );
    expect(find.text('Save changes'), findsOneWidget);

    await tester.enterText(subCategoryInput, 'Brunch');
    await tester.pump();
    final submitButton = find.byKey(
      const ValueKey('settings-quick-add-submit'),
    );
    for (var i = 0; i < 8; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(_quickAddKey) ?? '[]') as List;
    expect(saved, hasLength(1));
    expect(saved.single['id'], 'qa-edit');
    expect(saved.single['subCategory'], 'Brunch');
    expect(find.text('Brunch'), findsOneWidget);
    expect(find.text('Add shortcut'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings helper opens and closes a full-page route', (
    tester,
  ) async {
    var settingsClosed = false;
    await _pumpAtSize(
      tester,
      const Size(320, 568),
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                await showSettingsSheet(
                  context: context,
                  email: 'user@example.com',
                );
                settingsClosed = true;
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Personal categories'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(settingsClosed, isTrue);
    expect(find.text('Open settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}

/// The category sections sit below the Appearance and Security cards, so on
/// short viewports they can fall outside the ListView's lazy-build range
/// until scrolled into view.
Future<void> _scrollToCategories(WidgetTester tester, Finder target) async {
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
}
