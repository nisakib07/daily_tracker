import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/data/budget_advisor.dart';
import 'package:money_master/models/money_models.dart';

void main() {
  group('suggestBudgets', () {
    test('reports insufficient data under 14 days of history', () {
      final transactions = [
        _tx(
          id: 'i1',
          type: 'income',
          amount: 1000,
          daysAgo: 2,
          toAccount: true,
        ),
        _tx(
          id: 'e1',
          type: 'expense',
          amount: 200,
          daysAgo: 1,
          category: 'Food',
        ),
      ];

      final suggestion = suggestBudgets(transactions: transactions);

      expect(suggestion.hasEnoughData, isFalse);
      expect(suggestion.amounts, isEmpty);
    });

    test('reports no data when there is history but no income', () {
      final transactions = [
        for (var i = 1; i <= 20; i++)
          _tx(
            id: 'e$i',
            type: 'expense',
            amount: 300,
            daysAgo: i,
            category: 'Food',
          ),
      ];

      final suggestion = suggestBudgets(transactions: transactions);

      expect(suggestion.hasEnoughData, isFalse);
      expect(suggestion.amounts, isEmpty);
    });

    test(
      'keeps historical averages as-is when already under the savings target',
      () {
        final transactions = [
          _tx(
            id: 'income',
            type: 'income',
            amount: 60000,
            daysAgo: 25,
            toAccount: true,
          ),
          for (var i = 1; i <= 30; i++)
            _tx(
              id: 'e$i',
              type: 'expense',
              amount: 500,
              daysAgo: i,
              category: 'Food',
            ),
        ];

        final suggestion = suggestBudgets(transactions: transactions);

        expect(suggestion.hasEnoughData, isTrue);
        expect(suggestion.amounts, {'Food': 15000});
        expect(suggestion.summary, contains('already keep you'));
      },
    );

    test(
      'scales categories down proportionally when spend exceeds the savings target',
      () {
        final transactions = [
          _tx(
            id: 'income',
            type: 'income',
            amount: 20000,
            daysAgo: 25,
            toAccount: true,
          ),
          for (var i = 1; i <= 30; i++)
            _tx(
              id: 'e$i',
              type: 'expense',
              amount: 1000,
              daysAgo: i,
              category: 'Food',
            ),
        ];

        final suggestion = suggestBudgets(transactions: transactions);

        expect(suggestion.hasEnoughData, isTrue);
        // targetSpend = 20000 * 0.8 = 16000; historical avg spend was 30000,
        // scaled down to exactly the target for a single category.
        expect(suggestion.amounts, {'Food': 16000});
        expect(suggestion.summary, contains('capping total spending'));
      },
    );
  });

  group('suggestSpendingCuts', () {
    final now = DateTime.now();
    final thisMonthDay = DateTime(now.year, now.month, 10);
    final lastMonthDay = DateTime(now.year, now.month - 1, 10);

    test('returns nothing when spending is steady month over month', () {
      final transactions = [
        _txOn(
          id: 'income',
          type: 'income',
          amount: 50000,
          date: thisMonthDay,
          toAccount: true,
        ),
        _txOn(
          id: 'e-this',
          type: 'expense',
          amount: 5000,
          date: thisMonthDay,
          category: 'Food',
        ),
        _txOn(
          id: 'e-last',
          type: 'expense',
          amount: 4900,
          date: lastMonthDay,
          category: 'Food',
        ),
      ];

      final suggestions = suggestSpendingCuts(transactions: transactions);

      expect(suggestions, isEmpty);
    });

    test('flags a category that grew sharply month over month', () {
      final transactions = [
        _txOn(
          id: 'income',
          type: 'income',
          amount: 50000,
          date: thisMonthDay,
          toAccount: true,
        ),
        _txOn(
          id: 'e-this',
          type: 'expense',
          amount: 8000,
          date: thisMonthDay,
          category: 'Food',
        ),
        _txOn(
          id: 'e-last',
          type: 'expense',
          amount: 4000,
          date: lastMonthDay,
          category: 'Food',
        ),
      ];

      final suggestions = suggestSpendingCuts(transactions: transactions);

      expect(suggestions, isNotEmpty);
      final food = suggestions.firstWhere((s) => s.category == 'Food');
      expect(food.estimatedMonthlySaving, 4000);
      expect(food.message, contains('up 100%'));
    });

    test(
      'flags a discretionary category taking an outsized share of income',
      () {
        final transactions = [
          _txOn(
            id: 'income',
            type: 'income',
            amount: 20000,
            date: thisMonthDay,
            toAccount: true,
          ),
          _txOn(
            id: 'shopping',
            type: 'expense',
            amount: 5000,
            date: thisMonthDay,
            category: 'Shopping',
          ),
        ];

        final suggestions = suggestSpendingCuts(transactions: transactions);

        expect(suggestions, isNotEmpty);
        final shopping = suggestions.firstWhere(
          (s) => s.category == 'Shopping',
        );
        // benchmark is 10% of income (2000); over by 3000.
        expect(shopping.estimatedMonthlySaving, 3000);
        expect(shopping.message, contains('guideline'));
      },
    );
  });
}

TransactionRecord _tx({
  required String id,
  required String type,
  required double amount,
  required int daysAgo,
  bool toAccount = false,
  String? category,
}) {
  final date = DateTime.now().subtract(Duration(days: daysAgo));
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    toAccountId: toAccount ? 'account-1' : null,
    fromAccountId: toAccount ? null : 'account-1',
    category: category,
    occurredAt: date,
    createdAt: date,
  );
}

TransactionRecord _txOn({
  required String id,
  required String type,
  required double amount,
  required DateTime date,
  bool toAccount = false,
  String? category,
}) {
  return TransactionRecord(
    id: id,
    type: type,
    amount: amount,
    toAccountId: toAccount ? 'account-1' : null,
    fromAccountId: toAccount ? null : 'account-1',
    category: category,
    occurredAt: date,
    createdAt: date,
  );
}
