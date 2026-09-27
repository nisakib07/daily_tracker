import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/loan_position.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/models/money_models.dart';

var _sequence = 0;

TransactionRecord _loan(String type, double amount, {DateTime? at}) {
  final when = at ?? DateTime(2026, 9, 1);
  return TransactionRecord(
    id: 'loan-${_sequence++}',
    type: type,
    amount: amount,
    personId: 'rahim',
    occurredAt: when,
    createdAt: when,
  );
}

void main() {
  test('repaying more than you borrowed means they now owe you', () {
    final position = LoanPosition.from([
      _loan('borrow', 1000),
      _loan('repay', 1500),
    ]);

    expect(position.youOwe, 0);
    expect(position.theyOwe, 500);
    expect(position.netBalance, 500);
  });

  test('being paid back more than you lent means you now owe them', () {
    final position = LoanPosition.from([
      _loan('lend', 1000),
      _loan('receive', 1200),
    ]);

    expect(position.theyOwe, 0);
    expect(position.youOwe, 200);
    expect(position.netBalance, -200);
  });

  test('loans both ways keep both sides', () {
    final position = LoanPosition.from([
      _loan('lend', 1000),
      _loan('borrow', 300),
    ]);

    expect(position.theyOwe, 1000);
    expect(position.youOwe, 300);
    expect(position.netBalance, 700);
  });

  test('floating-point leftovers count as settled', () {
    final position = LoanPosition.from([
      _loan('lend', 0.1),
      _loan('lend', 0.2),
      _loan('receive', 0.3),
    ]);

    expect(position.netBalance, 0);
  });

  test('ignores other transactions and tracks the latest loan', () {
    final position = LoanPosition.from([
      _loan('lend', 100, at: DateTime(2026, 9, 3)),
      _loan('expense', 999, at: DateTime(2026, 9, 9)),
      _loan('receive', 40, at: DateTime(2026, 9, 5)),
    ]);

    expect(position.theyOwe, 60);
    expect(position.lastActivityAt, DateTime(2026, 9, 5));
  });

  test('the ledger keeps an overpaid person instead of dropping them', () {
    final created = DateTime(2026, 1, 1);
    final snapshot = DashboardSnapshot(
      accounts: [
        Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: created),
      ],
      people: [Person(id: 'rahim', name: 'Rahim', createdAt: created)],
      investments: const [],
      budgets: const [],
      transactions: [_loan('borrow', 1000), _loan('repay', 1500)],
    );

    expect(snapshot.ledgerEntries.single.netBalance, 500);
    expect(snapshot.totalToReceive, 500);
    expect(snapshot.totalToPay, 0);
  });
}
