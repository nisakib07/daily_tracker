import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:money_master/data/money_chat_context.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/models/money_models.dart';

void main() {
  group('buildMoneyChatContext', () {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 10);
    final lastMonth = DateTime(now.year, now.month - 1, 10);

    final account = Account(
      id: 'account-1',
      name: 'Cash',
      type: 'cash',
      createdAt: now,
    );

    test('covers a trailing 6-month window, oldest to newest', () {
      final snapshot = DashboardSnapshot(
        accounts: [account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: const [],
      );

      final context = buildMoneyChatContext(snapshot: snapshot);

      expect(context.monthlySummaries, hasLength(6));
      expect(
        context.monthlySummaries.first.month,
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 5)),
      );
      expect(
        context.monthlySummaries.last.month,
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month)),
      );
    });

    test('aggregates income and per-category expense by month', () {
      final transactions = [
        _tx(
          id: 'income-this',
          type: 'income',
          amount: 50000,
          date: thisMonth,
          toAccount: true,
        ),
        _tx(
          id: 'expense-this-food',
          type: 'expense',
          amount: 8000,
          date: thisMonth,
          category: 'Food',
        ),
        _tx(
          id: 'expense-this-transport',
          type: 'expense',
          amount: 2000,
          date: thisMonth,
          category: 'Transport',
        ),
        _tx(
          id: 'expense-last-food',
          type: 'expense',
          amount: 4000,
          date: lastMonth,
          category: 'Food',
        ),
      ];
      final snapshot = DashboardSnapshot(
        accounts: [account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: transactions,
      );

      final context = buildMoneyChatContext(snapshot: snapshot);

      final thisMonthSummary = context.monthlySummaries.last;
      expect(thisMonthSummary.income, 50000);
      expect(thisMonthSummary.expense, 10000);
      expect(thisMonthSummary.expenseByCategory, {
        'Food': 8000.0,
        'Transport': 2000.0,
      });

      final lastMonthSummary =
          context.monthlySummaries[context.monthlySummaries.length - 2];
      expect(lastMonthSummary.income, 0);
      expect(lastMonthSummary.expense, 4000);
      expect(lastMonthSummary.expenseByCategory, {'Food': 4000.0});
    });

    test('pulls balances straight from the snapshot, not raw transactions', () {
      final transactions = [
        _tx(
          id: 'income',
          type: 'income',
          amount: 10000,
          date: thisMonth,
          toAccount: true,
        ),
      ];
      final snapshot = DashboardSnapshot(
        accounts: [account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: transactions,
      );

      final context = buildMoneyChatContext(snapshot: snapshot);

      expect(context.currentBalance, snapshot.totalBalance);
      expect(context.totalToReceive, snapshot.totalToReceive);
      expect(context.totalToPay, snapshot.totalToPay);
      expect(context.currentBalance, 10000);
      expect(context.totalToReceive, 0);
      expect(context.totalToPay, 0);
    });

    test(
      'includes recent transactions with notes, newest first, within 90 days',
      () {
        final transactions = [
          _tx(
            id: 'income',
            type: 'income',
            amount: 50000,
            date: now.subtract(const Duration(days: 5)),
            toAccount: true,
          ),
          _tx(
            id: 'rickshaw-1',
            type: 'expense',
            amount: 30,
            date: now.subtract(const Duration(days: 3)),
            category: 'Transport',
            note: 'Rickshaw to office',
          ),
          _tx(
            id: 'rickshaw-2',
            type: 'expense',
            amount: 40,
            date: now.subtract(const Duration(days: 1)),
            category: 'Transport',
            note: 'Rickshaw home',
          ),
          _tx(
            id: 'too-old',
            type: 'expense',
            amount: 999,
            date: now.subtract(const Duration(days: 120)),
            category: 'Food',
            note: 'Outside the window',
          ),
        ];
        final snapshot = DashboardSnapshot(
          accounts: [account],
          people: const [],
          investments: const [],
          budgets: const [],
          transactions: transactions,
        );

        final context = buildMoneyChatContext(snapshot: snapshot);

        expect(context.recentTransactions, hasLength(3));
        expect(context.recentTransactions.first.note, 'Rickshaw home');
        expect(context.recentTransactions[1].note, 'Rickshaw to office');
        expect(
          context.recentTransactions.map((t) => t.note),
          isNot(contains('Outside the window')),
        );
      },
    );

    test('excludes loan/investment types from recent transactions', () {
      final transactions = [
        _tx(
          id: 'lend-1',
          type: 'lend',
          amount: 500,
          date: now.subtract(const Duration(days: 1)),
          note: 'Lent to a friend',
        ),
      ];
      final snapshot = DashboardSnapshot(
        accounts: [account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: transactions,
      );

      final context = buildMoneyChatContext(snapshot: snapshot);

      expect(context.recentTransactions, isEmpty);
    });

    test('caps recent transactions at 500 entries', () {
      final transactions = [
        for (var i = 0; i < 510; i++)
          _tx(
            id: 'e$i',
            type: 'expense',
            amount: 10,
            date: now.subtract(Duration(days: i % 89)),
            category: 'Food',
          ),
      ];
      final snapshot = DashboardSnapshot(
        accounts: [account],
        people: const [],
        investments: const [],
        budgets: const [],
        transactions: transactions,
      );

      final context = buildMoneyChatContext(snapshot: snapshot);

      expect(context.recentTransactions.length, 500);
    });
  });
}

TransactionRecord _tx({
  required String id,
  required String type,
  required double amount,
  required DateTime date,
  bool toAccount = false,
  String? category,
  String? note,
}) {
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    toAccountId: toAccount ? 'account-1' : null,
    fromAccountId: toAccount ? null : 'account-1',
    category: category,
    note: note,
    occurredAt: date,
    createdAt: date,
  );
}
