import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_state_widgets.dart';
import '../../shared/widgets/aurora_background.dart';

Future<void> showAnalyticsSheet({
  required BuildContext context,
  required DashboardSnapshot snapshot,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => AnalyticsSheet(snapshot: snapshot),
    ),
  );
}

class AnalyticsSheet extends StatelessWidget {
  const AnalyticsSheet({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final analytics = _AnalyticsData.fromSnapshot(snapshot);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Analytics'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 360 ? 12.0 : 18.0;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const ValueKey('analytics-workspace'),
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView(
                      key: const ValueKey('analytics-scroll-view'),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        14,
                        horizontal,
                        24,
                      ),
                      children: [
                        const _AnalyticsHeader(),
                        const SizedBox(height: 18),
                        _AnalyticsReportLayout(analytics: analytics),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsReportLayout extends StatelessWidget {
  const _AnalyticsReportLayout({required this.analytics});

  final _AnalyticsData analytics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final health = _HealthScoreCard(health: analytics.health);
        final flow = _MonthlyFlowCard(analytics: analytics);
        final insights = _InsightsCard(insights: analytics.insights);
        final categories = _CategorySpendingCard(rows: analytics.categoryRows);
        final heatmap = _SpendingHeatmapCard(analytics: analytics);

        if (!wide) {
          return Column(
            children: [
              health,
              const SizedBox(height: 12),
              flow,
              const SizedBox(height: 12),
              insights,
              const SizedBox(height: 12),
              categories,
              const SizedBox(height: 12),
              heatmap,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: health),
                const SizedBox(width: 14),
                Expanded(child: flow),
              ],
            ),
            const SizedBox(height: 14),
            insights,
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: categories),
                const SizedBox(width: 14),
                Expanded(child: heatmap),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.neonCyan, AppTheme.neonViolet],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonCyan.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.analytics_outlined, color: Color(0xFF04231A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                'Health, cash flow, and spending signals',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.neonCyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppTheme.neonCyan.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            DateFormat('MMM yyyy').format(DateTime.now()),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.neonCyan,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.health});

  final _HealthScore health;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(health.overall);

    return Card(
      key: const ValueKey('analytics-health-card'),
      elevation: 10,
      shadowColor: color.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: health.overall / 100,
                        strokeWidth: 9,
                        backgroundColor: color.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${health.overall}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            Text(
                              'Grade ${health.grade}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        health.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ScoreBar(metric: health.savingsRate),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.budgetAdherence),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.spendingConsistency),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.incomeStability),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.metric});

  final _HealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final progress = metric.maxScore == 0
        ? 0.0
        : metric.score / metric.maxScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 15, color: metric.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                metric.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${metric.status} ${metric.score}/${metric.maxScore}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress.clamp(0, 1).toDouble(),
            backgroundColor: metric.color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(metric.color),
          ),
        ),
      ],
    );
  }
}

class _MonthlyFlowCard extends StatelessWidget {
  const _MonthlyFlowCard({required this.analytics});

  final _AnalyticsData analytics;

  @override
  Widget build(BuildContext context) {
    final saved = analytics.thisMonthIncome - analytics.thisMonthExpense;
    final savingRate = analytics.thisMonthIncome > 0
        ? (saved / analytics.thisMonthIncome) * 100
        : 0.0;
    final savedColor = saved >= 0 ? AppTheme.neonEmerald : AppTheme.neonRose;

    return Card(
      key: const ValueKey('analytics-flow-card'),
      elevation: 10,
      shadowColor: AppTheme.neonCyan.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.waterfall_chart,
              title: 'Monthly Flow',
              subtitle: formatMonth(DateTime.now()),
              color: AppTheme.neonCyan,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Income',
                    value: formatMoney(analytics.thisMonthIncome),
                    color: AppTheme.neonEmerald,
                    icon: Icons.south_west,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Expense',
                    value: formatMoney(analytics.thisMonthExpense),
                    color: AppTheme.neonRose,
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: saved >= 0 ? 'Saved' : 'Shortfall',
                    value: formatMoney(saved.abs()),
                    color: savedColor,
                    icon: saved >= 0
                        ? Icons.savings_outlined
                        : Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Savings Rate',
                    value: '${savingRate.toStringAsFixed(0)}%',
                    color: savedColor,
                    icon: Icons.percent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<_Insight> insights;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('analytics-insights-card'),
      elevation: 10,
      shadowColor: AppTheme.neonAmber.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.auto_awesome,
              title: 'Smart Insights',
              subtitle: 'Updated from your transaction data',
              color: AppTheme.neonAmber,
            ),
            const SizedBox(height: 12),
            if (insights.isEmpty)
              const _EmptyInsight()
            else
              ...insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InsightTile(insight: insight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final _Insight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: 0.08),
        border: Border.all(color: insight.color.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, color: insight.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInsight extends StatelessWidget {
  const _EmptyInsight();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      icon: Icons.auto_awesome_outlined,
      message: 'Add more transactions to unlock automatic insights.',
      color: AppTheme.neonAmber,
    );
  }
}

class _CategorySpendingCard extends StatelessWidget {
  const _CategorySpendingCard({required this.rows});

  final List<_CategorySpend> rows;

  @override
  Widget build(BuildContext context) {
    final maxAmount = rows.isEmpty
        ? 0.0
        : rows.first.amount == 0
        ? 1.0
        : rows.first.amount;

    return Card(
      key: const ValueKey('analytics-category-card'),
      elevation: 10,
      shadowColor: AppTheme.neonRose.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.pie_chart_outline,
              title: 'Category Spending',
              subtitle: 'Top expense categories this month',
              color: AppTheme.neonRose,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const AppInlineNotice(
                icon: Icons.receipt_long_outlined,
                message: 'No expenses this month.',
                color: AppTheme.neonRose,
              )
            else
              ...rows
                  .take(6)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryBar(row: row, maxAmount: maxAmount),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.row, required this.maxAmount});

  final _CategorySpend row;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final progress = maxAmount <= 0 ? 0.0 : row.amount / maxAmount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.category,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              formatMoney(row.amount),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.neonRose,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress.clamp(0, 1).toDouble(),
            backgroundColor: AppTheme.neonRose.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(AppTheme.neonRose),
          ),
        ),
      ],
    );
  }
}

class _SpendingHeatmapCard extends StatelessWidget {
  const _SpendingHeatmapCard({required this.analytics});

  final _AnalyticsData analytics;

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    final firstDay = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = firstDay.weekday % 7;
    final maxSpend = analytics.dailySpending.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return Card(
      key: const ValueKey('analytics-heatmap-card'),
      elevation: 10,
      shadowColor: AppTheme.neonAmber.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.grid_view_rounded,
              title: 'Spending Heatmap',
              subtitle: formatMonth(month),
              color: AppTheme.neonAmber,
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                _DayLabel('S'),
                _DayLabel('M'),
                _DayLabel('T'),
                _DayLabel('W'),
                _DayLabel('T'),
                _DayLabel('F'),
                _DayLabel('S'),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offset + days,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();
                final day = index - offset + 1;
                final date = DateTime(month.year, month.month, day);
                final dateKey = _dateKey(date);
                final amount = analytics.dailySpending[dateKey] ?? 0;
                return _HeatCell(
                  key: ValueKey('heatmap-cell-$dateKey'),
                  day: day,
                  amount: amount,
                  maxAmount: maxSpend,
                  isToday: _isSameDay(date, DateTime.now()),
                  onTap: () => _showDayDetailSheet(
                    context: context,
                    date: date,
                    transactions:
                        analytics.dailyTransactions[dateKey] ?? const [],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily average',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${formatMoney(analytics.dailyAverage)}/day',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showDayDetailSheet({
  required BuildContext context,
  required DateTime date,
  required List<TransactionRecord> transactions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _DayDetailSheet(date: date, transactions: transactions),
  );
}

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.date, required this.transactions});

  final DateTime date;
  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    return SafeArea(
      child: Container(
        key: const ValueKey('day-detail-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        decoration: BoxDecoration(
          color: AppTheme.nebula,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.glassBorderStrong),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonRose.withValues(alpha: 0.12),
              blurRadius: 36,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(date),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transactions.isEmpty
                              ? 'No spending recorded'
                              : '${transactions.length} expense${transactions.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.neonRose,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: transactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: AppEmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Nothing spent this day',
                        message:
                            'Expenses recorded on this date will show up here.',
                        color: AppTheme.neonEmerald,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _DayDetailTile(transaction: transactions[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailTile extends StatelessWidget {
  const _DayDetailTile({required this.transaction});

  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.neonRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.north_east,
              color: AppTheme.neonRose,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category ?? 'Expense',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if ((transaction.note ?? '').isNotEmpty)
                  Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatMoney(transaction.amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.neonRose,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    super.key,
    required this.day,
    required this.amount,
    required this.maxAmount,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final double amount;
  final double maxAmount;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _heatColor(amount, maxAmount);
    return Tooltip(
      message: '$day: ${formatMoney(amount)}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(color: AppTheme.neonEmerald, width: 2)
                  : null,
            ),
            child: Text(
              '$day',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: amount > 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.health,
    required this.insights,
    required this.categoryRows,
    required this.dailySpending,
    required this.dailyTransactions,
    required this.dailyAverage,
    required this.thisMonthIncome,
    required this.thisMonthExpense,
    required this.lastMonthExpense,
  });

  final _HealthScore health;
  final List<_Insight> insights;
  final List<_CategorySpend> categoryRows;
  final Map<String, double> dailySpending;
  final Map<String, List<TransactionRecord>> dailyTransactions;
  final double dailyAverage;
  final double thisMonthIncome;
  final double thisMonthExpense;
  final double lastMonthExpense;

  factory _AnalyticsData.fromSnapshot(DashboardSnapshot snapshot) {
    final now = DateTime.now();
    final thisMonth = _monthOnly(now);
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonthTx = snapshot.transactions
        .where(
          (transaction) => _isSameMonth(transaction.displayDate, thisMonth),
        )
        .toList();
    final lastMonthTx = snapshot.transactions
        .where(
          (transaction) => _isSameMonth(transaction.displayDate, lastMonth),
        )
        .toList();

    final thisMonthIncome = _sumType(thisMonthTx, 'income');
    final thisMonthExpense = _sumType(thisMonthTx, 'expense');
    final lastMonthIncome = _sumType(lastMonthTx, 'income');
    final lastMonthExpense = _sumType(lastMonthTx, 'expense');

    final categoryRows = _categorySpending(thisMonthTx);
    final dailySpending = _dailySpending(thisMonthTx);
    final dailyTransactions = _dailyExpenseTransactions(thisMonthTx);
    final effectiveDays = _isSameMonth(now, thisMonth)
        ? now.day
        : DateUtils.getDaysInMonth(thisMonth.year, thisMonth.month);
    final dailyAverage = effectiveDays > 0
        ? thisMonthExpense / effectiveDays
        : 0.0;
    final budgets = snapshot.budgets
        .where((budget) => _isSameMonth(budget.month, thisMonth))
        .toList();
    final health = _calculateHealth(
      thisMonthIncome: thisMonthIncome,
      thisMonthExpense: thisMonthExpense,
      lastMonthIncome: lastMonthIncome,
      lastMonthExpense: lastMonthExpense,
      budgets: budgets,
      categoryRows: categoryRows,
    );
    final insights = _generateInsights(
      snapshot: snapshot,
      thisMonthTx: thisMonthTx,
      lastMonthTx: lastMonthTx,
      thisMonthIncome: thisMonthIncome,
      thisMonthExpense: thisMonthExpense,
      lastMonthExpense: lastMonthExpense,
      categoryRows: categoryRows,
      dailyAverage: dailyAverage,
    );

    return _AnalyticsData(
      health: health,
      insights: insights,
      categoryRows: categoryRows,
      dailySpending: dailySpending,
      dailyTransactions: dailyTransactions,
      dailyAverage: dailyAverage,
      thisMonthIncome: thisMonthIncome,
      thisMonthExpense: thisMonthExpense,
      lastMonthExpense: lastMonthExpense,
    );
  }
}

class _HealthScore {
  const _HealthScore({
    required this.overall,
    required this.grade,
    required this.message,
    required this.savingsRate,
    required this.budgetAdherence,
    required this.spendingConsistency,
    required this.incomeStability,
  });

  final int overall;
  final String grade;
  final String message;
  final _HealthMetric savingsRate;
  final _HealthMetric budgetAdherence;
  final _HealthMetric spendingConsistency;
  final _HealthMetric incomeStability;
}

class _HealthMetric {
  const _HealthMetric({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.icon,
    required this.color,
  });

  final String label;
  final int score;
  final int maxScore;
  final String status;
  final IconData icon;
  final Color color;
}

class _Insight {
  const _Insight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.priority,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double priority;
}

class _CategorySpend {
  const _CategorySpend({required this.category, required this.amount});

  final String category;
  final double amount;
}

_HealthScore _calculateHealth({
  required double thisMonthIncome,
  required double thisMonthExpense,
  required double lastMonthIncome,
  required double lastMonthExpense,
  required List<Budget> budgets,
  required List<_CategorySpend> categoryRows,
}) {
  final savingsRate = thisMonthIncome > 0
      ? ((thisMonthIncome - thisMonthExpense) / thisMonthIncome) * 100
      : 0.0;
  final savingsScore = savingsRate >= 30
      ? 30
      : savingsRate >= 20
      ? 25
      : savingsRate >= 10
      ? 20
      : savingsRate >= 0
      ? 15
      : 5;
  final savingsLabel = savingsRate >= 30
      ? 'Excellent'
      : savingsRate >= 20
      ? 'Great'
      : savingsRate >= 10
      ? 'Good'
      : savingsRate >= 0
      ? 'Fair'
      : 'Needs attention';

  var budgetScore = 15;
  var budgetLabel = 'No budgets';
  if (budgets.isNotEmpty) {
    final spending = {for (final row in categoryRows) row.category: row.amount};
    var adherenceTotal = 0.0;
    for (final budget in budgets) {
      final spent = spending[budget.category] ?? 0;
      final adherence = budget.amount > 0
          ? (1 - ((spent - budget.amount) / budget.amount)) * 100
          : 100.0;
      adherenceTotal += adherence.clamp(0, 100).toDouble();
    }
    final budgetValue = adherenceTotal / budgets.length;
    budgetScore = ((budgetValue / 100) * 25).round();
    budgetLabel = budgetValue >= 90
        ? 'Excellent'
        : budgetValue >= 70
        ? 'Good'
        : budgetValue >= 50
        ? 'Fair'
        : 'Over budget';
  }

  final expenseChange = lastMonthExpense > 0
      ? ((thisMonthExpense - lastMonthExpense).abs() / lastMonthExpense) * 100
      : 0.0;
  final consistencyScore = expenseChange <= 10
      ? 25
      : expenseChange <= 20
      ? 20
      : expenseChange <= 30
      ? 15
      : expenseChange <= 50
      ? 10
      : 5;
  final consistencyLabel = expenseChange <= 10
      ? 'Very stable'
      : expenseChange <= 20
      ? 'Stable'
      : expenseChange <= 30
      ? 'Moderate'
      : expenseChange <= 50
      ? 'Variable'
      : 'Volatile';

  final incomeChange = lastMonthIncome > 0
      ? ((thisMonthIncome - lastMonthIncome).abs() / lastMonthIncome) * 100
      : 0.0;
  final incomeScore = incomeChange <= 5
      ? 20
      : incomeChange <= 15
      ? 15
      : incomeChange <= 30
      ? 10
      : 5;
  final incomeLabel = incomeChange <= 5
      ? 'Very stable'
      : incomeChange <= 15
      ? 'Stable'
      : incomeChange <= 30
      ? 'Moderate'
      : 'Variable';

  final overall = savingsScore + budgetScore + consistencyScore + incomeScore;
  final grade = overall >= 85
      ? 'A'
      : overall >= 70
      ? 'B'
      : overall >= 55
      ? 'C'
      : overall >= 40
      ? 'D'
      : 'F';
  final message = overall >= 85
      ? 'Outstanding. Your money habits look strong.'
      : overall >= 70
      ? 'Great job. Your finances are moving well.'
      : overall >= 55
      ? 'You are doing okay, with room to improve.'
      : overall >= 40
      ? 'Review your spending and budgets this month.'
      : 'Time to tighten the basics and track closely.';

  return _HealthScore(
    overall: overall,
    grade: grade,
    message: message,
    savingsRate: _HealthMetric(
      label: 'Savings Rate',
      score: savingsScore,
      maxScore: 30,
      status: savingsLabel,
      icon: Icons.savings_outlined,
      color: AppTheme.neonEmerald,
    ),
    budgetAdherence: _HealthMetric(
      label: 'Budget Adherence',
      score: budgetScore,
      maxScore: 25,
      status: budgetLabel,
      icon: Icons.track_changes,
      color: AppTheme.neonCyan,
    ),
    spendingConsistency: _HealthMetric(
      label: 'Spending Consistency',
      score: consistencyScore,
      maxScore: 25,
      status: consistencyLabel,
      icon: Icons.timeline,
      color: AppTheme.neonRose,
    ),
    incomeStability: _HealthMetric(
      label: 'Income Stability',
      score: incomeScore,
      maxScore: 20,
      status: incomeLabel,
      icon: Icons.trending_up,
      color: AppTheme.neonAmber,
    ),
  );
}

List<_Insight> _generateInsights({
  required DashboardSnapshot snapshot,
  required List<TransactionRecord> thisMonthTx,
  required List<TransactionRecord> lastMonthTx,
  required double thisMonthIncome,
  required double thisMonthExpense,
  required double lastMonthExpense,
  required List<_CategorySpend> categoryRows,
  required double dailyAverage,
}) {
  final insights = <_Insight>[];

  if (thisMonthTx.isEmpty) {
    insights.add(
      const _Insight(
        title: 'Start tracking this month',
        description: 'Add transactions to see useful trends here.',
        icon: Icons.edit_note,
        color: AppTheme.neonCyan,
        priority: 10,
      ),
    );
  }

  if (categoryRows.isNotEmpty && thisMonthExpense > 0) {
    final top = categoryRows.first;
    final percent = ((top.amount / thisMonthExpense) * 100).round();
    insights.add(
      _Insight(
        title: 'Top spending: ${top.category}',
        description:
            '$percent% of this month expenses, ${formatMoney(top.amount)}.',
        icon: Icons.pie_chart_outline,
        color: AppTheme.neonCyan,
        priority: 8,
      ),
    );
  }

  if (thisMonthIncome > 0) {
    final savingsRate =
        ((thisMonthIncome - thisMonthExpense) / thisMonthIncome) * 100;
    if (savingsRate >= 20) {
      insights.add(
        _Insight(
          title: 'Saving ${savingsRate.round()}% of income',
          description: 'That is a healthy buffer for the month.',
          icon: Icons.check_circle_outline,
          color: AppTheme.neonEmerald,
          priority: 9,
        ),
      );
    } else if (savingsRate < 0) {
      insights.add(
        _Insight(
          title: 'Spending more than earning',
          description:
              'Shortfall is ${formatMoney((thisMonthExpense - thisMonthIncome).abs())}.',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.neonRose,
          priority: 10,
        ),
      );
    }
  }

  if (lastMonthExpense > 0) {
    final change =
        ((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100;
    if (change > 20) {
      insights.add(
        _Insight(
          title: 'Spending up ${change.round()}%',
          description:
              'This month is ${formatMoney(thisMonthExpense - lastMonthExpense)} higher than last month.',
          icon: Icons.trending_up,
          color: AppTheme.neonAmber,
          priority: 7,
        ),
      );
    } else if (change < -20) {
      insights.add(
        _Insight(
          title: 'Spending down ${change.abs().round()}%',
          description:
              'You spent ${formatMoney(lastMonthExpense - thisMonthExpense)} less than last month.',
          icon: Icons.trending_down,
          color: AppTheme.neonEmerald,
          priority: 7,
        ),
      );
    }
  }

  final totalInvested = snapshot.transactions
      .where((transaction) => transaction.type == 'invest')
      .fold<double>(0, (total, transaction) => total + transaction.amount);
  final totalReturned = snapshot.transactions
      .where((transaction) => transaction.type == 'invest_return')
      .fold<double>(0, (total, transaction) => total + transaction.amount);
  if (totalInvested > 0) {
    final net = totalReturned - totalInvested;
    final roi = (net / totalInvested) * 100;
    insights.add(
      _Insight(
        title: 'Investment portfolio',
        description:
            '${net >= 0 ? 'Profit' : 'Loss'} ${formatMoney(net.abs())}, ROI ${roi.toStringAsFixed(1)}%.',
        icon: Icons.business_center_outlined,
        color: net >= 0 ? AppTheme.neonEmerald : AppTheme.neonCyan,
        priority: 9.5,
      ),
    );
  }

  if (dailyAverage > 0 && lastMonthExpense > 0) {
    final now = DateTime.now();
    final projected =
        dailyAverage * DateUtils.getDaysInMonth(now.year, now.month);
    if (projected > lastMonthExpense * 1.2) {
      insights.add(
        _Insight(
          title: 'Projected to exceed last month',
          description:
              'At this pace, month-end spend may reach ${formatMoney(projected)}.',
          icon: Icons.lightbulb_outline,
          color: AppTheme.neonAmber,
          priority: 5,
        ),
      );
    }
  }

  insights.sort((a, b) => b.priority.compareTo(a.priority));
  return insights.take(4).toList();
}

double _sumType(List<TransactionRecord> transactions, String type) {
  return transactions
      .where((transaction) => transaction.type == type)
      .fold<double>(0, (total, transaction) => total + transaction.amount);
}

List<_CategorySpend> _categorySpending(List<TransactionRecord> transactions) {
  final spending = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.type != 'expense') continue;
    final category = (transaction.category ?? '').trim().isEmpty
        ? 'Uncategorized'
        : transaction.category!.trim();
    spending[category] = (spending[category] ?? 0) + transaction.amount;
  }

  final rows =
      spending.entries
          .map(
            (entry) => _CategorySpend(category: entry.key, amount: entry.value),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

Map<String, double> _dailySpending(List<TransactionRecord> transactions) {
  final spending = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.type != 'expense') continue;
    final key = _dateKey(transaction.displayDate);
    spending[key] = (spending[key] ?? 0) + transaction.amount;
  }
  return spending;
}

Map<String, List<TransactionRecord>> _dailyExpenseTransactions(
  List<TransactionRecord> transactions,
) {
  final byDate = <String, List<TransactionRecord>>{};
  for (final transaction in transactions) {
    if (transaction.type != 'expense') continue;
    final key = _dateKey(transaction.displayDate);
    (byDate[key] ??= []).add(transaction);
  }
  for (final entries in byDate.values) {
    entries.sort((a, b) => b.displayDate.compareTo(a.displayDate));
  }
  return byDate;
}

Color _scoreColor(int score) {
  if (score >= 85) return AppTheme.neonEmerald;
  if (score >= 70) return AppTheme.neonCyan;
  if (score >= 55) return AppTheme.neonAmber;
  return AppTheme.neonRose;
}

Color _heatColor(double amount, double maxAmount) {
  if (amount <= 0 || maxAmount <= 0) {
    return Colors.white.withValues(alpha: 0.06);
  }
  final ratio = amount / maxAmount;
  if (ratio < 0.2) return AppTheme.neonEmerald.withValues(alpha: 0.22);
  if (ratio < 0.4) return AppTheme.neonAmber.withValues(alpha: 0.25);
  if (ratio < 0.65) return AppTheme.neonAmber.withValues(alpha: 0.55);
  if (ratio < 0.85) return AppTheme.neonRose.withValues(alpha: 0.45);
  return AppTheme.neonRose.withValues(alpha: 0.72);
}

String _dateKey(DateTime value) {
  return DateFormat('yyyy-MM-dd').format(value);
}

DateTime _monthOnly(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month);
}

bool _isSameMonth(DateTime a, DateTime b) {
  final first = _monthOnly(a);
  final second = _monthOnly(b);
  return first.year == second.year && first.month == second.month;
}

bool _isSameDay(DateTime a, DateTime b) {
  final first = a.isUtc ? a.toLocal() : a;
  final second = b.isUtc ? b.toLocal() : b;
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
