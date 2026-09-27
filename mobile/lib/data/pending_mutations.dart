import '../core/date_times.dart';
import '../models/money_models.dart';
import 'money_repository.dart';
import 'offline_mutation_queue.dart';

/// Applies changes still waiting in the offline queue to [snapshot], so the
/// app shows them as soon as they're made instead of only once they sync.
///
/// Each case mirrors the matching branch of apply_money_mutation in
/// scripts/003_performance_security.sql, which is what will actually happen
/// on the server; keep the two consistent. Rows this creates are marked
/// pending, and new transactions get a [TransactionRecord.pendingIdPrefix]
/// id until the server assigns a real one. People and investments use the
/// mutation id, which the server also uses as their id.
///
/// Mutations whose ids are in [alreadySaved] were saved by the server but
/// aren't in [snapshot] yet (it was fetched before them). They're applied
/// the same way so a save shows at once, without waiting for the full
/// refresh, but their rows aren't marked pending.
DashboardSnapshot applyPendingMutations(
  DashboardSnapshot snapshot,
  List<QueuedMoneyMutation> pending, {
  Set<String> alreadySaved = const {},
}) {
  if (pending.isEmpty) return snapshot;

  final accounts = [...snapshot.accounts];
  final people = [...snapshot.people];
  final investments = [...snapshot.investments];
  final transactions = [...snapshot.transactions];
  final budgets = [...snapshot.budgets];

  for (final mutation in pending) {
    final payload = mutation.payload;
    final waiting = !alreadySaved.contains(mutation.id);
    String? text(String key) => _blankToNull(payload[key]);
    final occurredAt =
        parseNullableLocalDateTime(payload['occurred_at']) ??
        mutation.createdAt;

    void addTransaction({
      required String type,
      String? from,
      String? to,
      String? personId,
      String? investmentId,
      String? category,
      double? amount,
      DateTime? at,
    }) {
      _insertByDate(
        transactions,
        TransactionRecord(
          id: '${TransactionRecord.pendingIdPrefix}${mutation.id}',
          type: type,
          amount: amount ?? _number(payload['amount']),
          fromAccountId: from,
          toAccountId: to,
          personId: personId,
          investmentId: investmentId,
          category: category,
          note: text('note'),
          occurredAt: at ?? occurredAt,
          createdAt: mutation.createdAt,
          pending: waiting,
        ),
      );
    }

    switch (mutation.kind) {
      case 'money_in':
        addTransaction(
          type: 'income',
          to: text('account_id'),
          category: text('category'),
        );
      case 'money_out':
        addTransaction(
          type: 'expense',
          from: text('account_id'),
          category: text('category'),
        );
      case 'transfer':
        addTransaction(
          type: 'transfer',
          from: text('from_account_id'),
          to: text('to_account_id'),
          category: 'Transfer',
        );
      case 'loan':
        final type = text('type') ?? 'lend';
        final moneyOut = type == 'lend' || type == 'repay';
        addTransaction(
          type: type,
          from: moneyOut ? text('account_id') : null,
          to: moneyOut ? null : text('account_id'),
          personId: text('person_id'),
          category: text('category'),
        );
      case 'create_person':
        if (!people.any((person) => person.id == mutation.id)) {
          people.add(
            Person(
              id: mutation.id,
              name: text('name') ?? '',
              phone: text('phone'),
              note: text('note'),
              createdAt: mutation.createdAt,
            ),
          );
          people.sort((a, b) => a.name.compareTo(b.name));
        }
      case 'update_person':
        _replaceWhere(people, (person) => person.id == text('person_id'), (
          person,
        ) {
          return Person(
            id: person.id,
            name: text('name') ?? person.name,
            phone: text('phone'),
            note: text('note'),
            createdAt: person.createdAt,
          );
        });
      case 'delete_person':
        people.removeWhere((person) => person.id == text('person_id'));
      case 'update_account':
        final accountId = text('account_id');
        _replaceWhere(accounts, (account) => account.id == accountId, (
          account,
        ) {
          return Account(
            id: account.id,
            name: text('name') ?? account.name,
            type: account.type,
            createdAt: account.createdAt,
          );
        });
        final adjustment = _number(payload['adjustment_amount']);
        if (adjustment > 0) {
          final addMoney = payload['add_money'] == true;
          addTransaction(
            type: addMoney ? 'income' : 'expense',
            from: addMoney ? null : accountId,
            to: addMoney ? accountId : null,
            category: 'Balance Adjustment',
            amount: adjustment,
            at: mutation.createdAt,
          );
        }
      case 'create_investment':
        if (!investments.any((item) => item.id == mutation.id)) {
          investments.insert(
            0,
            Investment(
              id: mutation.id,
              name: text('name') ?? '',
              description: text('description'),
              status: 'active',
              createdAt: mutation.createdAt,
            ),
          );
        }
        addTransaction(
          type: 'invest',
          from: text('from_account_id'),
          investmentId: mutation.id,
          category: 'Investment',
        );
      case 'add_investment_funds':
        addTransaction(
          type: 'invest',
          from: text('from_account_id'),
          investmentId: text('investment_id'),
          category: 'Investment',
        );
      case 'investment_return':
        final investmentId = text('investment_id');
        addTransaction(
          type: 'invest_return',
          to: text('to_account_id'),
          investmentId: investmentId,
          category: 'Investment Return',
        );
        if (payload['close_investment'] == true) {
          _replaceWhere(investments, (item) => item.id == investmentId, (item) {
            return Investment(
              id: item.id,
              name: item.name,
              description: item.description,
              status: 'closed',
              createdAt: item.createdAt,
            );
          });
        }
      case 'update_transaction':
        final index = transactions.indexWhere(
          (item) => item.id == text('transaction_id'),
        );
        if (index == -1) break;
        final original = transactions.removeAt(index);
        _insertByDate(
          transactions,
          TransactionRecord(
            id: original.id,
            type: original.type,
            amount: _number(payload['amount']),
            fromAccountId: text('from_account_id'),
            toAccountId: text('to_account_id'),
            personId: text('person_id'),
            investmentId: original.investmentId,
            category: text('category'),
            note: text('note'),
            date: original.date,
            occurredAt: occurredAt,
            createdAt: original.createdAt,
            pending: waiting,
          ),
        );
      case 'delete_transaction':
        transactions.removeWhere((item) => item.id == text('transaction_id'));
      case 'delete_investment':
        final investmentId = text('investment_id');
        transactions.removeWhere((item) => item.investmentId == investmentId);
        investments.removeWhere((item) => item.id == investmentId);
      case 'replace_budgets':
      case 'clear_budgets':
        final month = parseNullableLocalDateTime(payload['month']);
        if (month == null) break;
        budgets.removeWhere((budget) => _sameMonth(budget.month, month));
        if (mutation.kind == 'clear_budgets') break;
        final entries = payload['budgets'];
        if (entries is! Map) break;
        for (final entry in entries.entries) {
          final category = entry.key.toString().trim();
          final amount = _number(entry.value);
          if (category.isEmpty || amount <= 0) continue;
          budgets.add(
            Budget(
              id: '${TransactionRecord.pendingIdPrefix}${mutation.id}-$category',
              month: DateTime(month.year, month.month),
              category: category,
              amount: amount,
              createdAt: mutation.createdAt,
              updatedAt: mutation.createdAt,
            ),
          );
        }
    }
  }

  return DashboardSnapshot(
    accounts: accounts,
    people: people,
    investments: investments,
    transactions: transactions,
    budgets: budgets,
    // The server's balances and monthly totals don't include the pending
    // changes, so let the snapshot compute them from its transactions.
    serverSummary: null,
  );
}

/// Inserts [transaction] before the first older one, keeping the list in
/// the server's newest-first order.
void _insertByDate(
  List<TransactionRecord> transactions,
  TransactionRecord transaction,
) {
  final index = transactions.indexWhere(
    (item) => item.occurredAt.isBefore(transaction.occurredAt),
  );
  transactions.insert(index == -1 ? transactions.length : index, transaction);
}

void _replaceWhere<T>(
  List<T> items,
  bool Function(T item) test,
  T Function(T item) replace,
) {
  for (var index = 0; index < items.length; index++) {
    if (test(items[index])) items[index] = replace(items[index]);
  }
}

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String? _blankToNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
