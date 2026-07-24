import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/settings/settings_sheet.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _incomeKey = 'dmt_custom_income_categories';
const _expenseKey = 'dmt_custom_expense_categories';
const _longCategory =
    'A consulting and professional services category with an exceptionally long display name';

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
