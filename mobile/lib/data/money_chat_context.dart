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

/// A single income/expense line item, including its note - the monthly
/// summaries above only carry category totals, so a question about a
/// specific note (e.g. "how much on rickshaw") has nothing to match
/// against without this.
class RecentTransaction {
  const RecentTransaction({
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
  });

  final String date;
  final String type;
  final double amount;
  final String category;
  final String note;

  Map<String, dynamic> toJson() => {
    'date': date,
    'type': type,
    'amount': amount,
    'category': category,
    'note': note,
  };
}

/// The bounded context handed to the "Ask Your Money" chat endpoint: current
/// balances, a trailing window of monthly summaries, and a capped window of
/// recent line items - never the full transaction list.
class MoneyChatContext {
  const MoneyChatContext({
    required this.currentBalance,
    required this.totalToReceive,
    required this.totalToPay,
    required this.monthlySummaries,
    this.recentTransactions = const [],
  });

  final double currentBalance;
  final double totalToReceive;
  final double totalToPay;
  final List<MonthlyMoneySummary> monthlySummaries;
  final List<RecentTransaction> recentTransactions;

  Map<String, dynamic> toJson() => {
    'currentBalance': currentBalance,
    'totalToReceive': totalToReceive,
    'totalToPay': totalToPay,
    'monthlySummaries': [
      for (final summary in monthlySummaries) summary.toJson(),
    ],
    'recentTransactions': [
      for (final transaction in recentTransactions) transaction.toJson(),
    ],
  };
}

const _monthlySummaryWindow = 6;
const _recentTransactionWindowDays = 90;
const _recentTransactionCap = 500;

/// Groups the trailing [_monthlySummaryWindow] calendar months of
/// transactions into per-month income/expense-by-category totals, and
/// separately lists up to [_recentTransactionCap] individual income/expense
/// transactions from the trailing [_recentTransactionWindowDays] days (most
/// recent first) so note-level questions can be answered too.
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

  final recentWindowStart = now.subtract(
    const Duration(days: _recentTransactionWindowDays),
  );
  final recentTransactions =
      snapshot.transactions
          .where(
            (t) =>
                (t.type == 'income' || t.type == 'expense') &&
                !t.displayDate.isBefore(recentWindowStart) &&
                !t.displayDate.isAfter(now),
          )
          .toList()
        ..sort((a, b) => b.displayDate.compareTo(a.displayDate));

  return MoneyChatContext(
    currentBalance: snapshot.totalBalance,
    totalToReceive: snapshot.totalToReceive,
    totalToPay: snapshot.totalToPay,
    monthlySummaries: summaries,
    recentTransactions: recentTransactions
        .take(_recentTransactionCap)
        .map(
          (t) => RecentTransaction(
            date: DateFormat('yyyy-MM-dd').format(t.displayDate),
            type: t.type,
            amount: t.amount,
            category: _normalizedCategory(t.category),
            note: t.note?.trim() ?? '',
          ),
        )
        .toList(),
  );
}

String _normalizedCategory(String? category) {
  final trimmed = category?.trim() ?? '';
  return trimmed.isEmpty ? 'Uncategorized' : trimmed;
}

bool _isSameMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}
