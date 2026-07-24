import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/app_logger.dart';
import 'features/app/money_master_app.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Unhandled Flutter framework error',
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error('Unhandled platform error', error, stackTrace);
        return true;
      };

      if (AppConfig.hasSupabaseConfig) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
        );
      }

      runApp(const ProviderScope(child: MoneyMasterApp()));
    },
    (error, stackTrace) {
      AppLogger.error('Unhandled asynchronous error', error, stackTrace);
    },
  );
}
