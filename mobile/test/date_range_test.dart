import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/date_times.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/transactions/transaction_entry_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 9, 28, 15, 30);

  test('offers history back to 2000 and nothing after today', () {
    final range = pickableDateRange(DateTime(2026, 9, 20, 10), now: now);

    expect(range.first, DateTime(2000));
    expect(range.last, DateTime(2026, 9, 28));
  });

  test('widens to include a record dated outside that range', () {
    final old = pickableDateRange(DateTime(1998, 3, 4, 9), now: now);
    expect(old.first, DateTime(1998, 3, 4));
    expect(old.last, DateTime(2026, 9, 28));

    final ahead = pickableDateRange(DateTime(2026, 10, 2, 18), now: now);
    expect(ahead.first, DateTime(2000));
    expect(ahead.last, DateTime(2026, 10, 2));
  });

  testWidgets('editing a 2019 transaction can open its date picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final created = DateTime(2019, 5, 1, 12);
    final cash = Account(
      id: 'cash',
      name: 'Cash',
      type: 'cash',
      createdAt: created,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: EditTransactionSheet(
          transaction: TransactionRecord(
            id: 'old-expense',
            type: 'expense',
            amount: 300,
            fromAccountId: 'cash',
            category: 'Food',
            occurredAt: created,
            createdAt: created,
          ),
          accounts: [AccountBalance(account: cash, balance: 0)],
          people: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateButton = find.text('May 1, 2019');
    await tester.ensureVisible(dateButton);
    await tester.tap(dateButton);
    await tester.pumpAndSettle();

    // Before, the picker's range started in 2020 and it refused to open.
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
