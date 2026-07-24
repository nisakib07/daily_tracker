import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/date_times.dart';
import 'package:money_master/models/money_models.dart';

void main() {
  test('Supabase timestamps round-trip back to the selected local day', () {
    final selectedLateNight = DateTime(2026, 7, 17, 23, 45, 12);

    final serialized = toSupabaseTimestamp(selectedLateNight);
    final parsed = parseLocalDateTime(serialized);

    expect(serialized, endsWith('Z'));
    expect(parsed.year, selectedLateNight.year);
    expect(parsed.month, selectedLateNight.month);
    expect(parsed.day, selectedLateNight.day);
    expect(parsed.hour, selectedLateNight.hour);
    expect(parsed.minute, selectedLateNight.minute);
  });

  test('TransactionRecord parses UTC occurred_at as local display time', () {
    final selectedDate = DateTime(2026, 7, 17, 23, 30);
    final transaction = TransactionRecord.fromJson({
      'id': 'timezone-transaction',
      'type': 'income',
      'amount': 100,
      'to_account_id': 'cash',
      'occurred_at': toSupabaseTimestamp(selectedDate),
      'created_at': toSupabaseTimestamp(selectedDate),
    });

    expect(transaction.displayDate.year, 2026);
    expect(transaction.displayDate.month, 7);
    expect(transaction.displayDate.day, 17);
  });
}
