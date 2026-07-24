import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/models/money_models.dart';

void main() {
  test('account balances include income, expense, and transfers', () {
    final snapshot = _snapshot(
      accounts: [_cash, _wallet, _card],
      transactions: [
        _transaction(
          id: 'income',
          type: 'income',
          amount: 1000,
          toAccountId: _cash.id,
        ),
        _transaction(
          id: 'expense',
          type: 'expense',
          amount: 250,
          fromAccountId: _cash.id,
        ),
        _transaction(
          id: 'transfer-cash-wallet',
          type: 'transfer',
          amount: 300,
          fromAccountId: _cash.id,
          toAccountId: _wallet.id,
        ),
        _transaction(
          id: 'transfer-wallet-card',
          type: 'transfer',
          amount: 100,
          fromAccountId: _wallet.id,
          toAccountId: _card.id,
        ),
      ],
    );

    final balances = {
      for (final item in snapshot.accountBalances)
        item.account.id: item.balance,
    };

    expect(balances[_cash.id], 450);
    expect(balances[_wallet.id], 200);
    expect(balances[_card.id], 100);
    expect(snapshot.totalBalance, 750);
    expect(snapshot.accountBalances.map((item) => item.account.id), [
      _cash.id,
      _wallet.id,
      _card.id,
    ]);
  });

  test('monthly totals count current-month income and expense only', () {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 5, 9);
    final previousMonth = DateTime(now.year, now.month - 1, 5, 9);

    final snapshot = _snapshot(
      transactions: [
        _transaction(
          id: 'current-income',
          type: 'income',
          amount: 500,
          toAccountId: _cash.id,
          occurredAt: currentMonth,
        ),
        _transaction(
          id: 'current-expense',
          type: 'expense',
          amount: 175,
          fromAccountId: _cash.id,
          occurredAt: currentMonth,
        ),
        _transaction(
          id: 'old-income',
          type: 'income',
          amount: 900,
          toAccountId: _cash.id,
          occurredAt: previousMonth,
        ),
        _transaction(
          id: 'current-transfer',
          type: 'transfer',
          amount: 80,
          fromAccountId: _cash.id,
          toAccountId: _wallet.id,
          occurredAt: currentMonth,
        ),
      ],
    );

    expect(snapshot.monthIncome, 500);
    expect(snapshot.monthExpense, 175);
  });

  test('recent transactions returns the first twelve entries', () {
    final transactions = List.generate(14, (index) {
      return _transaction(
        id: 'transaction-$index',
        type: 'income',
        amount: index + 1,
        toAccountId: _cash.id,
      );
    });

    final snapshot = _snapshot(transactions: transactions);

    expect(snapshot.recentTransactions, hasLength(12));
    expect(snapshot.recentTransactions.first.id, 'transaction-0');
    expect(snapshot.recentTransactions.last.id, 'transaction-11');
  });

  test('server summary supplies optimized balances and current totals', () {
    final now = DateTime.now();
    final snapshot = DashboardSnapshot(
      accounts: [
        Account(id: 'cash', name: 'Cash', type: 'cash', createdAt: now),
      ],
      people: const [],
      investments: const [],
      transactions: const [],
      budgets: const [],
      serverSummary: DashboardServerSummary(
        month: DateTime(now.year, now.month),
        accountBalances: const {'cash': 750},
        monthIncome: 900,
        monthExpense: 150,
        transactionCount: 12,
      ),
    );

    expect(snapshot.accountBalances.single.balance, 750);
    expect(snapshot.monthIncome, 900);
    expect(snapshot.monthExpense, 150);
  });

  test('activity date uses occurred_at when a legacy date differs', () {
    final occurredAt = DateTime(2026, 7, 10, 18, 30);
    final legacyDate = DateTime(2026, 7, 9);
    final transaction = TransactionRecord(
      id: 'transaction-with-legacy-date',
      type: 'income',
      amount: 123,
      toAccountId: 'cash',
      date: legacyDate,
      occurredAt: occurredAt,
      createdAt: occurredAt,
    );

    expect(transaction.displayDate, occurredAt);
  });

  test('ledger entries calculate payables and receivables', () {
    final snapshot = _snapshot(
      people: [_alex, _mina, _settled],
      transactions: [
        _transaction(
          id: 'lend-alex',
          type: 'lend',
          amount: 500,
          fromAccountId: _cash.id,
          personId: _alex.id,
        ),
        _transaction(
          id: 'receive-alex',
          type: 'receive',
          amount: 150,
          toAccountId: _cash.id,
          personId: _alex.id,
        ),
        _transaction(
          id: 'borrow-mina',
          type: 'borrow',
          amount: 700,
          toAccountId: _wallet.id,
          personId: _mina.id,
        ),
        _transaction(
          id: 'repay-mina',
          type: 'repay',
          amount: 100,
          fromAccountId: _wallet.id,
          personId: _mina.id,
        ),
        _transaction(
          id: 'lend-settled',
          type: 'lend',
          amount: 100,
          fromAccountId: _cash.id,
          personId: _settled.id,
        ),
        _transaction(
          id: 'receive-settled',
          type: 'receive',
          amount: 100,
          toAccountId: _cash.id,
          personId: _settled.id,
        ),
      ],
    );

    expect(snapshot.ledgerEntries, hasLength(2));
    expect(snapshot.ledgerEntries.first.person.id, _mina.id);
    expect(snapshot.ledgerEntries.first.youOwe, 600);
    expect(snapshot.ledgerEntries.first.netBalance, -600);
    expect(snapshot.ledgerEntries.last.person.id, _alex.id);
    expect(snapshot.ledgerEntries.last.theyOwe, 350);
    expect(snapshot.ledgerEntries.last.netBalance, 350);
    expect(snapshot.totalToReceive, 350);
    expect(snapshot.totalToPay, 600);
  });
}

DashboardSnapshot _snapshot({
  List<Account>? accounts,
  List<Person>? people,
  List<TransactionRecord>? transactions,
}) {
  return DashboardSnapshot(
    accounts: accounts ?? [_cash, _wallet],
    people: people ?? const [],
    investments: const [],
    transactions: transactions ?? const [],
    budgets: const [],
  );
}

TransactionRecord _transaction({
  required String id,
  required String type,
  required double amount,
  String? fromAccountId,
  String? toAccountId,
  String? personId,
  DateTime? occurredAt,
}) {
  final timestamp = occurredAt ?? _baseDate;
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    personId: personId,
    occurredAt: timestamp,
    createdAt: timestamp,
  );
}

final _baseDate = DateTime(2026, 7, 10, 12);

final _cash = Account(
  id: 'cash',
  name: 'Cash',
  type: 'cash',
  createdAt: _baseDate,
);

final _wallet = Account(
  id: 'wallet',
  name: 'bKash',
  type: 'wallet',
  createdAt: _baseDate,
);

final _card = Account(
  id: 'card',
  name: 'Card',
  type: 'card',
  createdAt: _baseDate,
);

final _alex = Person(id: 'alex', name: 'Alex', createdAt: _baseDate);
final _mina = Person(id: 'mina', name: 'Mina', createdAt: _baseDate);
final _settled = Person(id: 'settled', name: 'Settled', createdAt: _baseDate);
