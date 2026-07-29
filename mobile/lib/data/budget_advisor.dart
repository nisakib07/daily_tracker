import '../core/formatters.dart';
import '../models/money_models.dart';

/// A proposed monthly budget per category, computed purely from the user's
/// own transaction history - no external service, no network call.
class BudgetSuggestion {
  const BudgetSuggestion({
    required this.amounts,
    required this.summary,
    required this.hasEnoughData,
  });

  final Map<String, double> amounts;
  final String summary;
  final bool hasEnoughData;
}

/// A single, concrete place to trim spending, with an estimated monthly
/// saving attached.
class SpendCutSuggestion {
  const SpendCutSuggestion({
    required this.category,
    required this.message,
    required this.estimatedMonthlySaving,
  });

  final String category;
  final String message;
  final double estimatedMonthlySaving;
}

const _budgetWindowDays = 90;
const _budgetMinHistoryDays = 14;
const _targetSavingsRate = 0.2;

/// The trailing-90-day aggregation both the local budget suggestion and the
/// AI-backed one are built from - computed once so neither has to
/// re-derive it from raw transactions.
class BudgetHistorySummary {
  const BudgetHistorySummary({
    required this.hasEnoughData,
    required this.insufficientDataMessage,
    required this.daysOfHistory,
    required this.avgMonthlyIncome,
    required this.avgCategorySpending,
  });

  final bool hasEnoughData;
  final String insufficientDataMessage;
  final int daysOfHistory;
  final double avgMonthlyIncome;
  final Map<String, double> avgCategorySpending;
}

BudgetHistorySummary summarizeBudgetHistory({
  required List<TransactionRecord> transactions,
}) {
  final now = DateTime.now();
  final windowStart = now.subtract(const Duration(days: _budgetWindowDays));

  DateTime? earliest;
  for (final transaction in transactions) {
    final date = transaction.displayDate;
    if (earliest == null || date.isBefore(earliest)) earliest = date;
  }
  final daysOfHistory = earliest == null
      ? 0
      : now.difference(earliest).inDays.clamp(0, _budgetWindowDays);

  if (daysOfHistory < _budgetMinHistoryDays) {
    return BudgetHistorySummary(
      hasEnoughData: false,
      insufficientDataMessage:
          'Not enough history yet — add a few weeks of transactions before '
          'asking for a budget suggestion.',
      daysOfHistory: daysOfHistory,
      avgMonthlyIncome: 0,
      avgCategorySpending: const {},
    );
  }

  var totalIncome = 0.0;
  final categorySpend = <String, double>{};
  for (final transaction in transactions) {
    final date = transaction.displayDate;
    if (date.isBefore(windowStart) || date.isAfter(now)) continue;

    if (transaction.type == 'income') {
      totalIncome += transaction.amount;
    } else if (transaction.type == 'expense') {
      final category = _normalizedCategory(transaction.category);
      categorySpend[category] =
          (categorySpend[category] ?? 0) + transaction.amount;
    }
  }

  if (totalIncome <= 0) {
    return BudgetHistorySummary(
      hasEnoughData: false,
      insufficientDataMessage:
          'No income recorded yet — log some income transactions first so '
          'we can suggest a budget.',
      daysOfHistory: daysOfHistory,
      avgMonthlyIncome: 0,
      avgCategorySpending: const {},
    );
  }

  final months = daysOfHistory / 30.0;
  return BudgetHistorySummary(
    hasEnoughData: true,
    insufficientDataMessage: '',
    daysOfHistory: daysOfHistory,
    avgMonthlyIncome: totalIncome / months,
    avgCategorySpending: {
      for (final entry in categorySpend.entries)
        entry.key: entry.value / months,
    },
  );
}

/// Proposes a monthly budget per category from the trailing 90 days of
/// transactions: average monthly spend per category, scaled down
/// proportionally (preserving the user's actual spending mix) if the total
/// would eat into a ~20% savings rate.
BudgetSuggestion suggestBudgets({
  required List<TransactionRecord> transactions,
}) {
  final history = summarizeBudgetHistory(transactions: transactions);
  if (!history.hasEnoughData) {
    return BudgetSuggestion(
      amounts: const {},
      summary: history.insufficientDataMessage,
      hasEnoughData: false,
    );
  }

  final avgCategorySpend = history.avgCategorySpending;
  final avgMonthlyIncome = history.avgMonthlyIncome;
  final totalAvgSpend = avgCategorySpend.values.fold(0.0, (a, b) => a + b);
  final targetSpend = avgMonthlyIncome * (1 - _targetSavingsRate);
  final savingsPercent = (_targetSavingsRate * 100).round();

  Map<String, double> suggested;
  String summary;
  if (totalAvgSpend <= targetSpend) {
    suggested = avgCategorySpend;
    summary =
        'Based on the last ${history.daysOfHistory} days (avg ${formatMoney(avgMonthlyIncome)}/month '
        'income), your current habits already keep you around a '
        '$savingsPercent% savings rate — these budgets match what you '
        'typically spend.';
  } else {
    final scale = targetSpend / totalAvgSpend;
    suggested = {
      for (final entry in avgCategorySpend.entries)
        entry.key: entry.value * scale,
    };
    summary =
        'Based on the last ${history.daysOfHistory} days (avg ${formatMoney(avgMonthlyIncome)}/month '
        'income), capping total spending at ${formatMoney(targetSpend)} '
        'keeps you at a $savingsPercent% savings rate.';
  }

  final rounded = {
    for (final entry in suggested.entries)
      if (entry.value > 0) entry.key: _roundToNearest(entry.value, 50),
  };

  return BudgetSuggestion(
    amounts: rounded,
    summary: summary,
    hasEnoughData: true,
  );
}

/// This-month vs last-month spending, shared by the local spend-cut
/// suggestion and the AI-backed one.
class SpendCutContext {
  const SpendCutContext({
    required this.thisMonthIncome,
    required this.thisMonthCategorySpending,
    required this.lastMonthCategorySpending,
  });

  final double thisMonthIncome;
  final Map<String, double> thisMonthCategorySpending;
  final Map<String, double> lastMonthCategorySpending;
}

SpendCutContext summarizeSpendCutContext({
  required List<TransactionRecord> transactions,
}) {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  final thisMonthTx = transactions
      .where((t) => _isSameMonth(t.displayDate, thisMonth))
      .toList();
  final lastMonthTx = transactions
      .where((t) => _isSameMonth(t.displayDate, lastMonth))
      .toList();

  return SpendCutContext(
    thisMonthIncome: _sumType(thisMonthTx, 'income'),
    thisMonthCategorySpending: _categoryTotals(thisMonthTx),
    lastMonthCategorySpending: _categoryTotals(lastMonthTx),
  );
}

/// Looks for concrete places to cut spending using only data the app
/// already tracks: month-over-month category growth, and categories that
/// take up an unusually large share of this month's income.
List<SpendCutSuggestion> suggestSpendingCuts({
  required List<TransactionRecord> transactions,
}) {
  final context = summarizeSpendCutContext(transactions: transactions);
  final thisMonthIncome = context.thisMonthIncome;
  final thisMonthCategorySpend = context.thisMonthCategorySpending;
  final lastMonthCategorySpend = context.lastMonthCategorySpending;

  final candidates = <SpendCutSuggestion>[];

  for (final entry in thisMonthCategorySpend.entries) {
    final lastAmount = lastMonthCategorySpend[entry.key] ?? 0;
    if (lastAmount <= 0) continue;
    final change = entry.value - lastAmount;
    final changePercent = change / lastAmount;
    if (changePercent > 0.25 && change >= 200) {
      candidates.add(
        SpendCutSuggestion(
          category: entry.key,
          message:
              '${entry.key} spending is up ${(changePercent * 100).round()}% '
              'from last month (${formatMoney(lastAmount)} to '
              '${formatMoney(entry.value)}). Trimming back toward last '
              "month's level would save about ${formatMoney(change)}.",
          estimatedMonthlySaving: change,
        ),
      );
    }
  }

  const discretionaryBenchmarks = {
    'Shopping': 0.10,
    'Entertainment': 0.08,
    'Food': 0.15,
  };
  if (thisMonthIncome > 0) {
    for (final entry in thisMonthCategorySpend.entries) {
      final benchmark = discretionaryBenchmarks[entry.key];
      if (benchmark == null) continue;
      final share = entry.value / thisMonthIncome;
      if (share <= benchmark) continue;
      final over = entry.value - (thisMonthIncome * benchmark);
      if (over < 200) continue;
      candidates.add(
        SpendCutSuggestion(
          category: entry.key,
          message:
              '${entry.key} is ${(share * 100).round()}% of your income '
              'this month — above the typical ${(benchmark * 100).round()}% '
              'guideline. Bringing it down could free up about '
              '${formatMoney(over)}.',
          estimatedMonthlySaving: over,
        ),
      );
    }
  }

  final byCategory = <String, SpendCutSuggestion>{};
  for (final candidate in candidates) {
    final existing = byCategory[candidate.category];
    if (existing == null ||
        candidate.estimatedMonthlySaving > existing.estimatedMonthlySaving) {
      byCategory[candidate.category] = candidate;
    }
  }

  final result = byCategory.values.toList()
    ..sort(
      (a, b) => b.estimatedMonthlySaving.compareTo(a.estimatedMonthlySaving),
    );
  return result.take(3).toList();
}

String _normalizedCategory(String? category) {
  final trimmed = category?.trim() ?? '';
  return trimmed.isEmpty ? 'Uncategorized' : trimmed;
}

Map<String, double> _categoryTotals(List<TransactionRecord> transactions) {
  final totals = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.type != 'expense') continue;
    final category = _normalizedCategory(transaction.category);
    totals[category] = (totals[category] ?? 0) + transaction.amount;
  }
  return totals;
}

double _sumType(List<TransactionRecord> transactions, String type) {
  return transactions
      .where((t) => t.type == type)
      .fold(0.0, (sum, t) => sum + t.amount);
}

bool _isSameMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}

double _roundToNearest(double value, double step) {
  return (value / step).round() * step;
}
