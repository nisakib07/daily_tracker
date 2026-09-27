import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/network_error.dart';
import 'app_logger.dart';

/// Turns an error into a sentence someone can act on, for messages shown in
/// forms and screens. Raw exception text ("PostgrestException(message: ...,
/// code: 23503, ...)") used to be shown as is. The raw error still goes to
/// the log for debugging.
String friendlyErrorMessage(Object error) {
  final message = _describe(error);
  AppLogger.error('Shown to the user as "$message"', error, StackTrace.current);
  return message;
}

String _describe(Object error) {
  if (error is TimeoutException) {
    return 'The server took too long to answer. Please try again.';
  }
  if (isIoNetworkError(error) ||
      error is ClientException ||
      error is AuthRetryableFetchException) {
    return 'No internet connection. Check your connection and try again.';
  }
  // Supabase Auth messages are already written for people.
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '23505') return 'That already exists.';
    if (code == '23503') {
      return 'An account, person or investment it uses no longer exists. '
          'Refresh and try again.';
    }
    if (code == 'P0002') return 'It no longer exists. Refresh and try again.';
    if (code.startsWith('22') || code.startsWith('23')) {
      return "Some of the details aren't valid.";
    }
    // 42501: row-level security refused it; PGRST3xx: missing/expired JWT.
    if (code == '42501' || code.startsWith('PGRST3')) {
      return 'Your session has expired. Sign out and back in, then try again.';
    }
    return "The server couldn't do that right now. Please try again.";
  }
  return 'Something went wrong. Please try again.';
}
