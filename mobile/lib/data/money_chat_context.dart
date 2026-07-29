import 'package:intl/intl.dart';

import 'money_repository.dart';

/// One calendar month's income/expense totals, aggregated from the user's
/// own transaction history - never raw transaction rows - to keep what's
/// sent to the AI both small and privacy-conscious.
class MonthlyMoneySummary {
  const MonthlyMoneySummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.expenseByCategory,
  });

  final String month;
  final double income;
  final double expense;
  final Map<String, double> expenseByCategory;

  Map<String, dynamic> toJson() => {
    'month': month,
    'income': income,
    'expense': expense,
    'expenseByCategory': [
      for (final entry in expenseByCategory.entries)
        {'category': entry.key, 'amount': entry.value},
    ],
  };
}

/// The bounded context handed to the "Ask Your Money" chat endpoint: current
/// balances plus a trailing window of monthly summaries, rather than the
/// full transaction list.
class MoneyChatContext {
  const MoneyChatContext({
    required this.currentBalance,
    required this.totalToReceive,
    required this.totalToPay,
    required this.monthlySummaries,
  });

  final double currentBalance;
  final double totalToReceive;
  final double totalToPay;
  final List<MonthlyMoneySummary> monthlySummaries;

  Map<String, dynamic> toJson() => {
    'currentBalance': currentBalance,
    'totalToReceive': totalToReceive,
    'totalToPay': totalToPay,
    'monthlySummaries': [
      for (final summary in monthlySummaries) summary.toJson(),
    ],
  };
}

const _monthlySummaryWindow = 6;

/// Groups the trailing [_monthlySummaryWindow] calendar months of
/// transactions into per-month income/expense-by-category totals.
MoneyChatContext buildMoneyChatContext({required DashboardSnapshot snapshot}) {
  final now = DateTime.now();
  final months = [
    for (var i = _monthlySummaryWindow - 1; i >= 0; i--)
      DateTime(now.year, now.month - i),
  ];

  final summaries = months.map((month) {
    final monthTx = snapshot.transactions.where(
      (t) => _isSameMonth(t.displayDate, month),
    );

    var income = 0.0;
    final expenseByCategory = <String, double>{};
    for (final transaction in monthTx) {
      if (transaction.type == 'income') {
        income += transaction.amount;
      } else if (transaction.type == 'expense') {
        final category = _normalizedCategory(transaction.category);
        expenseByCategory[category] =
            (expenseByCategory[category] ?? 0) + transaction.amount;
      }
    }
    final expense = expenseByCategory.values.fold(0.0, (a, b) => a + b);

    return MonthlyMoneySummary(
      month: DateFormat('yyyy-MM').format(month),
      income: income,
      expense: expense,
      expenseByCategory: expenseByCategory,
    );
  }).toList();

  return MoneyChatContext(
    currentBalance: snapshot.totalBalance,
    totalToReceive: snapshot.totalToReceive,
    totalToPay: snapshot.totalToPay,
    monthlySummaries: summaries,
  );
}

String _normalizedCategory(String? category) {
  final trimmed = category?.trim() ?? '';
  return trimmed.isEmpty ? 'Uncategorized' : trimmed;
}

bool _isSameMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}
