import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/app_lock_controller.dart';
import 'package:money_master/features/auth/app_lock_gate.dart';
import 'package:money_master/shared/theme/app_theme.dart';

class _FakeAppLock extends AppLockController {
  _FakeAppLock({required this.enabled});

  final bool enabled;
  bool unlockSucceeds = false;
  int prompts = 0;

  @override
  AppLockSettings build() {
    return AppLockSettings(loaded: true, enabled: enabled, isSupported: true);
  }

  @override
  Future<bool> authenticate() async {
    prompts++;
    return unlockSucceeds;
  }
}

class _Harness {
  const _Harness(this.lock, this.session, this.navigatorKey);

  final _FakeAppLock lock;
  final ValueNotifier<bool> session;
  final GlobalKey<NavigatorState> navigatorKey;
}

const _lockedTitle = 'Money Master is locked';

/// Builds the app the way MoneyMasterApp does: the lock wraps the Navigator.
Future<_Harness> _pumpApp(
  WidgetTester tester, {
  required bool signedIn,
  bool enabled = true,
  bool unlockSucceeds = false,
}) async {
  final lock = _FakeAppLock(enabled: enabled)..unlockSucceeds = unlockSucceeds;
  final session = ValueNotifier<bool>(signedIn);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appLockProvider.overrideWith(() => lock)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        navigatorKey: navigatorKey,
        builder: (context, child) => AppLockGate(
          navigatorKey: navigatorKey,
          signedIn: session,
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('Balances'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('Analytics details')),
                    ),
                  ),
                  child: const Text('Open analytics'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(lock, session, navigatorKey);
}

Future<void> _leaveAndReturn(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('locks on cold start and hides the app until unlocked', (
    tester,
  ) async {
    final app = await _pumpApp(tester, signedIn: true);

    expect(find.text(_lockedTitle), findsOneWidget);
    expect(find.text('Balances'), findsNothing);
    expect(app.lock.prompts, 1);

    app.lock.unlockSucceeds = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text(_lockedTitle), findsNothing);
    expect(find.text('Balances'), findsOneWidget);
  });

  testWidgets('returning to the app covers screens opened on top', (
    tester,
  ) async {
    final app = await _pumpApp(tester, signedIn: true, unlockSucceeds: true);
    expect(find.text('Balances'), findsOneWidget);

    await tester.tap(find.text('Open analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Analytics details'), findsOneWidget);

    app.lock.unlockSucceeds = false;
    await _leaveAndReturn(tester);

    // The lock used to live inside the first page, so this pushed screen
    // stayed visible above it.
    expect(find.text(_lockedTitle), findsOneWidget);
    expect(find.text('Analytics details'), findsNothing);

    app.lock.unlockSucceeds = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    // The screen the user had open is still there after unlocking.
    expect(find.text('Analytics details'), findsOneWidget);
  });

  testWidgets('signing in does not ask to unlock straight away', (
    tester,
  ) async {
    final app = await _pumpApp(tester, signedIn: false);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text(_lockedTitle), findsNothing);

    app.session.value = true;
    await tester.pumpAndSettle();

    expect(find.text(_lockedTitle), findsNothing);
    expect(find.text('Balances'), findsOneWidget);
    expect(app.lock.prompts, 0);

    // It still locks the next time the app comes back from the background.
    await _leaveAndReturn(tester);
    expect(find.text(_lockedTitle), findsOneWidget);
  });

  testWidgets('signing out closes every screen and removes the lock', (
    tester,
  ) async {
    final app = await _pumpApp(tester, signedIn: true, unlockSucceeds: true);
    await tester.tap(find.text('Open analytics'));
    await tester.pumpAndSettle();

    app.lock.unlockSucceeds = false;
    await _leaveAndReturn(tester);
    expect(find.text(_lockedTitle), findsOneWidget);

    app.session.value = false;
    await tester.pumpAndSettle();

    expect(find.text(_lockedTitle), findsNothing);
    expect(find.text('Analytics details'), findsNothing);
    expect(find.text('Balances'), findsOneWidget);
    expect(app.navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('does nothing while app lock is off', (tester) async {
    final app = await _pumpApp(tester, signedIn: true, enabled: false);
    expect(find.text('Balances'), findsOneWidget);

    await _leaveAndReturn(tester);

    expect(find.text(_lockedTitle), findsNothing);
    expect(app.lock.prompts, 0);
  });

  for (final size in const [Size(320, 568), Size(1440, 900)]) {
    testWidgets('lock screen fits at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpApp(tester, signedIn: true);

      expect(find.text(_lockedTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
