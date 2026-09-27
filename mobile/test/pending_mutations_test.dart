import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/date_times.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/data/offline_mutation_queue.dart';
import 'package:money_master/data/pending_mutations.dart';
import 'package:money_master/data/secure_cache_store.dart';
import 'package:money_master/models/money_models.dart';

final _queue = OfflineMutationQueue(
  store: MemoryDashboardCacheStore(),
  key: 'pending-test',
);

QueuedMoneyMutation _mutation(String kind, Map<String, dynamic> payload) {
  return _queue.create(kind, payload);
}

final _created = DateTime(2026, 1, 1);
final _cash = Account(
  id: 'cash',
  name: 'Cash',
  type: 'cash',
  createdAt: _created,
);
final _bkash = Account(
  id: 'bkash',
  name: 'bKash',
  type: 'wallet',
  createdAt: _created,
);

TransactionRecord _income(String id, double amount, DateTime at) {
  return TransactionRecord(
    id: id,
    type: 'income',
    amount: amount,
    toAccountId: 'cash',
    category: 'Salary',
    occurredAt: at,
    createdAt: at,
  );
}

DashboardSnapshot _snapshot({
  List<TransactionRecord>? transactions,
  List<Person> people = const [],
  List<Investment> investments = const [],
  List<Budget> budgets = const [],
  DashboardServerSummary? serverSummary,
}) {
  return DashboardSnapshot(
    accounts: [_cash, _bkash],
    people: people,
    investments: investments,
    transactions:
        transactions ??
        [
          _income('newer', 1000, DateTime(2026, 9, 20, 10)),
          _income('older', 500, DateTime(2026, 9, 10, 10)),
        ],
    budgets: budgets,
    serverSummary: serverSummary,
  );
}

double _balance(DashboardSnapshot snapshot, String accountId) {
  return snapshot.accountBalances
      .firstWhere((item) => item.account.id == accountId)
      .balance;
}

String _at(DateTime value) => toSupabaseTimestamp(value);

void main() {
  test('returns the snapshot unchanged when nothing is pending', () {
    final snapshot = _snapshot();
    expect(
      identical(applyPendingMutations(snapshot, const []), snapshot),
      isTrue,
    );
  });

  test('an offline expense appears in date order and lowers the balance', () {
    final expense = _mutation('money_out', {
      'amount': 250,
      'account_id': 'cash',
      'category': 'Food',
      'occurred_at': _at(DateTime(2026, 9, 15, 13)),
      'note': ' lunch ',
    });

    final shown = applyPendingMutations(_snapshot(), [expense]);

    expect(shown.transactions.map((item) => item.id), [
      'newer',
      'pending-${expense.id}',
      'older',
    ]);
    final added = shown.transactions[1];
    expect(added.type, 'expense');
    expect(added.fromAccountId, 'cash');
    expect(added.category, 'Food');
    expect(added.note, 'lunch');
    expect(added.pending, isTrue);
    expect(added.existsOnServer, isFalse);
    expect(_balance(shown, 'cash'), 1250);
  });

  test('server balances are ignored while changes are pending', () {
    final server = _snapshot(
      serverSummary: DashboardServerSummary(
        month: DateTime(2026, 9),
        accountBalances: const {'cash': 1500, 'bkash': 0},
        monthIncome: 1500,
        monthExpense: 0,
        transactionCount: 2,
      ),
    );
    final transfer = _mutation('transfer', {
      'amount': 400,
      'from_account_id': 'cash',
      'to_account_id': 'bkash',
      'occurred_at': _at(DateTime(2026, 9, 21)),
    });

    final shown = applyPendingMutations(server, [transfer]);

    expect(shown.serverSummary, isNull);
    expect(_balance(shown, 'cash'), 1100);
    expect(_balance(shown, 'bkash'), 400);
  });

  test('a person added offline can be lent money before either syncs', () {
    final person = _mutation('create_person', {'name': ' Rahim ', 'phone': ''});
    final loan = _mutation('loan', {
      'type': 'lend',
      'amount': 300,
      'account_id': 'cash',
      'person_id': person.id,
      'category': 'Loan Given',
      'occurred_at': _at(DateTime(2026, 9, 22)),
    });

    final shown = applyPendingMutations(_snapshot(), [person, loan]);

    // The server gives the new person the mutation id too.
    expect(shown.people.single.id, person.id);
    expect(shown.people.single.name, 'Rahim');
    expect(shown.people.single.phone, isNull);
    expect(shown.ledgerEntries.single.theyOwe, 300);
    expect(_balance(shown, 'cash'), 1200);
  });

  test('editing and deleting existing transactions apply in order', () {
    final edit = _mutation('update_transaction', {
      'transaction_id': 'older',
      'amount': 800,
      'occurred_at': _at(DateTime(2026, 9, 25, 9)),
      'from_account_id': null,
      'to_account_id': 'bkash',
      'person_id': null,
      'category': 'Freelance',
      'note': 'edited',
    });
    final delete = _mutation('delete_transaction', {'transaction_id': 'newer'});

    final shown = applyPendingMutations(_snapshot(), [edit, delete]);

    final edited = shown.transactions.single;
    expect(edited.id, 'older');
    expect(edited.existsOnServer, isTrue);
    expect(edited.pending, isTrue);
    expect(edited.amount, 800);
    expect(edited.toAccountId, 'bkash');
    expect(edited.category, 'Freelance');
    expect(_balance(shown, 'cash'), 0);
    expect(_balance(shown, 'bkash'), 800);
  });

  test('investments: create, return with close, and delete', () {
    final create = _mutation('create_investment', {
      'name': 'Savings bond',
      'amount': 600,
      'from_account_id': 'cash',
      'occurred_at': _at(DateTime(2026, 9, 21)),
    });
    final payout = _mutation('investment_return', {
      'investment_id': create.id,
      'amount': 650,
      'to_account_id': 'bkash',
      'close_investment': true,
      'occurred_at': _at(DateTime(2026, 9, 26)),
    });

    final shown = applyPendingMutations(_snapshot(), [create, payout]);
    expect(shown.investments.single.id, create.id);
    expect(shown.investments.single.status, 'closed');
    expect(_balance(shown, 'cash'), 900);
    expect(_balance(shown, 'bkash'), 650);

    final removal = _mutation('delete_investment', {
      'investment_id': create.id,
    });
    final afterDelete = applyPendingMutations(_snapshot(), [
      create,
      payout,
      removal,
    ]);
    expect(afterDelete.investments, isEmpty);
    expect(afterDelete.transactions.map((item) => item.id), ['newer', 'older']);
  });

  test('renaming an account with an adjustment', () {
    final update = _mutation('update_account', {
      'account_id': 'cash',
      'name': 'Wallet cash',
      'adjustment_amount': 100,
      'add_money': false,
      'note': '',
    });

    final shown = applyPendingMutations(_snapshot(), [update]);

    expect(
      shown.accounts.firstWhere((item) => item.id == 'cash').name,
      'Wallet cash',
    );
    expect(_balance(shown, 'cash'), 1400);
    final adjustment = shown.transactions.firstWhere((item) => item.pending);
    expect(adjustment.category, 'Balance Adjustment');
    expect(adjustment.note, isNull);
  });

  test('budgets for a month are replaced or cleared', () {
    final existing = [
      Budget(
        id: 'b1',
        month: DateTime(2026, 9),
        category: 'Food',
        amount: 4000,
        createdAt: _created,
        updatedAt: _created,
      ),
      Budget(
        id: 'b2',
        month: DateTime(2026, 8),
        category: 'Food',
        amount: 3000,
        createdAt: _created,
        updatedAt: _created,
      ),
    ];
    final replace = _mutation('replace_budgets', {
      'month': DateTime(2026, 9).toIso8601String(),
      'budgets': {'Food': 5000, 'Transport': 0, ' ': 100},
    });

    final replaced = applyPendingMutations(_snapshot(budgets: existing), [
      replace,
    ]);
    final september = replaced.budgets.where((b) => b.month.month == 9);
    expect(september.single.amount, 5000);
    expect(replaced.budgets.where((b) => b.month.month == 8).single.id, 'b2');

    final clear = _mutation('clear_budgets', {
      'month': DateTime(2026, 9).toIso8601String(),
    });
    final cleared = applyPendingMutations(_snapshot(budgets: existing), [
      clear,
    ]);
    expect(cleared.budgets.single.id, 'b2');
  });
}
