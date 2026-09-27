import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:money_master/core/error_messages.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _noInternet =
    'No internet connection. Check your connection and try again.';

PostgrestException _postgrest(String code) {
  return PostgrestException(message: 'raw database text', code: code);
}

void main() {
  test('connection problems', () {
    expect(
      friendlyErrorMessage(TimeoutException('slow')),
      'The server took too long to answer. Please try again.',
    );
    expect(
      friendlyErrorMessage(const SocketException('Failed host lookup')),
      _noInternet,
    );
    expect(friendlyErrorMessage(ClientException('closed')), _noInternet);
    expect(
      friendlyErrorMessage(AuthRetryableFetchException(message: 'fetch')),
      _noInternet,
    );
  });

  test('database rejections', () {
    expect(friendlyErrorMessage(_postgrest('23505')), 'That already exists.');
    expect(
      friendlyErrorMessage(_postgrest('23503')),
      'An account, person or investment it uses no longer exists. '
      'Refresh and try again.',
    );
    expect(
      friendlyErrorMessage(_postgrest('P0002')),
      'It no longer exists. Refresh and try again.',
    );
    for (final code in ['22P02', '23514']) {
      expect(
        friendlyErrorMessage(_postgrest(code)),
        "Some of the details aren't valid.",
      );
    }
    for (final code in ['42501', 'PGRST301']) {
      expect(
        friendlyErrorMessage(_postgrest(code)),
        'Your session has expired. Sign out and back in, then try again.',
      );
    }
    expect(
      friendlyErrorMessage(_postgrest('503')),
      "The server couldn't do that right now. Please try again.",
    );
  });

  test('auth messages pass through; anything else is generic', () {
    expect(
      friendlyErrorMessage(const AuthException('Invalid login credentials')),
      'Invalid login credentials',
    );
    expect(
      friendlyErrorMessage(const FormatException('bad')),
      'Something went wrong. Please try again.',
    );
  });

  testWidgets('a failed save shows the friendly message, not the raw error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: TransactionEntrySheet(
          kind: TransactionEntryKind.expense,
          accounts: [
            AccountBalance(
              account: Account(
                id: 'cash',
                name: 'Cash',
                type: 'cash',
                createdAt: DateTime(2026, 1, 1),
              ),
              balance: 500,
            ),
          ],
          dataSource: _FailingDataSource(_postgrest('23503')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    final save = find.widgetWithText(FilledButton, 'Add Expense');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer exists'), findsOneWidget);
    expect(find.textContaining('PostgrestException'), findsNothing);
    expect(find.textContaining('raw database text'), findsNothing);
  });
}

class _FailingDataSource implements MoneyDataSource {
  _FailingDataSource(this.error);

  final Object error;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.error(error);
}
