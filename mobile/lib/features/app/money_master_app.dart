import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/daily_reminder_controller.dart';
import '../../core/theme_mode_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../auth/app_lock_gate.dart';
import '../auth/auth_gate.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class MoneyMasterApp extends ConsumerWidget {
  const MoneyMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Touching this provider on every launch re-syncs the scheduled daily
    // reminder in case the OS cleared it (force-stop, battery optimization).
    ref.read(dailyReminderProvider);
    return MaterialApp(
      title: 'Money Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorKey: _navigatorKey,
      // Above the Navigator, so the lock covers every screen and dialog.
      builder: (context, child) =>
          AppLockGate(navigatorKey: _navigatorKey, child: child!),
      home: const AuthGate(),
    );
  }
}
