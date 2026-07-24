import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void error(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'money_master',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );

    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }
}
