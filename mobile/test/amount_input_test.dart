import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/amount_input.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads amounts the way people type them', () {
    expect(parseAmount('250'), 250);
    expect(parseAmount(' 18.50 '), 18.5);
    expect(parseAmount('1,000'), 1000);
    expect(parseAmount('1,25,000'), 125000);
    expect(parseAmount('৳ 2 500.5'), 2500.5);
    expect(parseAmount('.5'), 0.5);
    expect(parseAmount('7.'), 7);
  });

  test('rejects what double.tryParse would have let through', () {
    for (final text in [
      '',
      '-10',
      '+10',
      '1e5',
      'NaN',
      'Infinity',
      '12.345',
      '1.2.3',
      'abc',
      '.',
    ]) {
      expect(parseAmount(text), isNull, reason: text);
    }
  });

  test('validation messages say what is wrong', () {
    expect(validateAmount(''), 'Enter an amount');
    expect(validateAmount('0'), 'Enter an amount greater than 0');
    expect(validateAmount('12.345'), 'Use at most 2 decimal places');
    expect(validateAmount('1e5'), 'Enter a number, like 250 or 18.50');
    expect(validateAmount('-10'), 'Enter a number, like 250 or 18.50');
    expect(
      validateAmount('2000000000'),
      "That's over ৳100 crore. Check the amount",
    );
    expect(validateAmount('1,000'), isNull);
    expect(validateAmount('1000000000'), isNull);
  });

  test('optional fields and zero', () {
    expect(validateAmount('', required: false), isNull);
    expect(validateAmount('0', allowZero: true), isNull);
    expect(validateAmount('abc', required: false), isNotNull);
  });

  testWidgets('an expense of "1,000" saves as 1000', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dataSource = _RecordingDataSource();
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
              balance: 5000,
            ),
          ],
          dataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '1,000',
    );
    final save = find.widgetWithText(FilledButton, 'Add Expense');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(dataSource.amounts, [1000]);
  });
}

class _RecordingDataSource implements MoneyDataSource {
  final amounts = <double>[];

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    amounts.add(amount);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
