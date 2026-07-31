import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../data/ai_service.dart';
import '../../data/budget_advisor.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_state_widgets.dart';
import '../../shared/widgets/aurora_background.dart';

Future<void> showAnalyticsSheet({
  required BuildContext context,
  required DashboardSnapshot snapshot,
  AiService? aiService,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          AnalyticsSheet(snapshot: snapshot, aiService: aiService),
    ),
  );
}

class AnalyticsSheet extends StatelessWidget {
  const AnalyticsSheet({super.key, required this.snapshot, this.aiService});

  final DashboardSnapshot snapshot;
  final AiService? aiService;

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
                        _AnalyticsReportLayout(
                          analytics: analytics,
                          aiService: aiService,
                        ),
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
  const _AnalyticsReportLayout({required this.analytics, this.aiService});

  final _AnalyticsData analytics;
  final AiService? aiService;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final health = _HealthScoreCard(
          health: analytics.health,
          aiService: aiService,
        );
        final flow = _MonthlyFlowCard(analytics: analytics);
        final forecast = _CashFlowForecastCard(
          forecast: analytics.cashFlowForecast,
        );
        final insights = _InsightsCard(insights: analytics.insights);
        final spendCuts = _SpendCutSuggestionsCard(
          suggestions: analytics.spendCutSuggestions,
          spendContext: analytics.spendCutContext,
          aiService: aiService,
        );
        final categories = _CategorySpendingCard(rows: analytics.categoryRows);
        final heatmap = _SpendingHeatmapCard(analytics: analytics);

        if (!wide) {
          return Column(
            children: [
              health,
              const SizedBox(height: 12),
              flow,
              const SizedBox(height: 12),
              forecast,
              const SizedBox(height: 12),
              insights,
              const SizedBox(height: 12),
              spendCuts,
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
            forecast,
            const SizedBox(height: 14),
            insights,
            const SizedBox(height: 14),
            spendCuts,
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

class _HealthScoreCard extends StatefulWidget {
  const _HealthScoreCard({required this.health, this.aiService});

  final _HealthScore health;
  final AiService? aiService;

  @override
  State<_HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<_HealthScoreCard> {
  late final AiService _aiService = widget.aiService ?? AiService();
  String? _aiExplanation;
  bool _isLoading = false;
  String? _error;

  Future<void> _fetchExplanation() async {
    final health = widget.health;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final explanation = await _aiService.explainHealthScore(
        overall: health.overall,
        grade: health.grade,
        metrics: [
          _metricInput(health.savingsRate),
          _metricInput(health.budgetAdherence),
          _metricInput(health.spendingConsistency),
          _metricInput(health.incomeStability),
          _metricInput(health.financialCushion),
        ],
      );
      if (!mounted) return;
      setState(() {
        _aiExplanation = explanation;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'AI unavailable — showing the default summary instead.';
        _isLoading = false;
      });
    }
  }

  AiHealthMetricInput _metricInput(_HealthMetric metric) {
    return AiHealthMetricInput(
      label: metric.label,
      score: metric.score,
      maxScore: metric.maxScore,
      status: metric.status,
      insufficientData: metric.insufficientData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = widget.health;
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Financial Health',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('health-explain-ai'),
                            tooltip: 'Explain with AI',
                            onPressed: _isLoading ? null : _fetchExplanation,
                            icon: _isLoading
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiExplanation ?? health.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              AppInlineNotice(
                icon: Icons.info_outline,
                message: _error!,
                color: AppTheme.neonAmber,
              ),
            ],
            const SizedBox(height: 16),
            _ScoreBar(metric: health.savingsRate),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.budgetAdherence),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.spendingConsistency),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.incomeStability),
            const SizedBox(height: 10),
            _ScoreBar(metric: health.financialCushion),
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
    final progress = metric.insufficientData || metric.maxScore == 0
        ? 0.0
        : metric.score / metric.maxScore;
    final iconColor = metric.insufficientData
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : metric.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 15, color: iconColor),
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
              metric.insufficientData
                  ? metric.status
                  : '${metric.status} ${metric.score}/${metric.maxScore}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (metric.insufficientData)
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: DottedProgressPlaceholder(color: iconColor),
          )
        else
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

/// A muted, empty-looking bar for metrics that don't have enough data yet -
/// distinct from a real 0-score bar, which would otherwise look identical.
class DottedProgressPlaceholder extends StatelessWidget {
  const DottedProgressPlaceholder({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(99),
      ),
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

class _CashFlowForecastCard extends StatelessWidget {
  const _CashFlowForecastCard({required this.forecast});

  final _CashFlowForecast forecast;

  @override
  Widget build(BuildContext context) {
    final color = _forecastColor(forecast.status);

    return Card(
      key: const ValueKey('analytics-forecast-card'),
      elevation: 10,
      shadowColor: color.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: _forecastIcon(forecast.status),
              title: 'Cash Flow Forecast',
              subtitle: forecast.status == _ForecastStatus.insufficientData
                  ? 'Not enough history yet'
                  : 'Based on the last ${forecast.daysOfHistory} days',
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              forecast.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (forecast.status != _ForecastStatus.insufficientData) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Current balance',
                      value: formatMoney(forecast.currentBalance),
                      color: AppTheme.neonCyan,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Daily net change',
                      value:
                          '${forecast.avgDailyNetChange >= 0 ? '+' : '-'}'
                          '${formatMoney(forecast.avgDailyNetChange.abs())}',
                      color: forecast.avgDailyNetChange >= 0
                          ? AppTheme.neonEmerald
                          : AppTheme.neonRose,
                      icon: forecast.avgDailyNetChange >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _forecastColor(_ForecastStatus status) {
  switch (status) {
    case _ForecastStatus.growing:
    case _ForecastStatus.stable:
      return AppTheme.neonEmerald;
    case _ForecastStatus.declining:
      return AppTheme.neonAmber;
    case _ForecastStatus.critical:
      return AppTheme.neonRose;
    case _ForecastStatus.insufficientData:
      return AppTheme.neonCyan;
  }
}

IconData _forecastIcon(_ForecastStatus status) {
  switch (status) {
    case _ForecastStatus.growing:
      return Icons.trending_up;
    case _ForecastStatus.stable:
      return Icons.trending_flat;
    case _ForecastStatus.declining:
      return Icons.query_stats;
    case _ForecastStatus.critical:
      return Icons.warning_amber_rounded;
    case _ForecastStatus.insufficientData:
      return Icons.hourglass_empty;
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

class _SpendCutSuggestionsCard extends StatefulWidget {
  const _SpendCutSuggestionsCard({
    required this.suggestions,
    required this.spendContext,
    this.aiService,
  });

  final List<SpendCutSuggestion> suggestions;
  final SpendCutContext spendContext;
  final AiService? aiService;

  @override
  State<_SpendCutSuggestionsCard> createState() =>
      _SpendCutSuggestionsCardState();
}

class _SpendCutSuggestionsCardState extends State<_SpendCutSuggestionsCard> {
  late final AiService _aiService = widget.aiService ?? AiService();
  List<AiSpendCutSuggestion>? _aiSuggestions;
  bool _isLoading = false;
  String? _error;

  Future<void> _fetchAiSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _aiService.suggestSpendingCuts(
        income: widget.spendContext.thisMonthIncome,
        thisMonthCategorySpending:
            widget.spendContext.thisMonthCategorySpending,
        lastMonthCategorySpending:
            widget.spendContext.lastMonthCategorySpending,
      );
      if (!mounted) return;
      setState(() {
        _aiSuggestions = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'AI unavailable — showing the on-device estimate instead.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiSuggestions = _aiSuggestions;

    return Card(
      key: const ValueKey('analytics-spend-cuts-card'),
      elevation: 10,
      shadowColor: AppTheme.neonEmerald.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _CardTitle(
                    icon: Icons.savings_outlined,
                    title: 'Where You Could Save',
                    subtitle: 'Based on your spending patterns',
                    color: AppTheme.neonEmerald,
                  ),
                ),
                IconButton(
                  key: const ValueKey('spend-cuts-ask-ai'),
                  tooltip: 'Get AI suggestions',
                  onPressed: _isLoading ? null : _fetchAiSuggestions,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.neonEmerald,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppTheme.neonEmerald,
                        ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppInlineNotice(
                icon: Icons.info_outline,
                message: _error!,
                color: AppTheme.neonAmber,
              ),
            ],
            const SizedBox(height: 12),
            if (aiSuggestions != null)
              if (aiSuggestions.isEmpty)
                const AppInlineNotice(
                  icon: Icons.thumb_up_outlined,
                  message:
                      'No obvious cuts to suggest — your spending looks steady.',
                  color: AppTheme.neonEmerald,
                )
              else
                ...aiSuggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SpendCutTile(
                      category: suggestion.category,
                      message: suggestion.message,
                      estimatedMonthlySaving: suggestion.estimatedMonthlySaving,
                    ),
                  ),
                )
            else if (widget.suggestions.isEmpty)
              const AppInlineNotice(
                icon: Icons.thumb_up_outlined,
                message:
                    'No obvious cuts to suggest — your spending looks steady.',
                color: AppTheme.neonEmerald,
              )
            else
              ...widget.suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SpendCutTile(
                    category: suggestion.category,
                    message: suggestion.message,
                    estimatedMonthlySaving: suggestion.estimatedMonthlySaving,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpendCutTile extends StatelessWidget {
  const _SpendCutTile({
    required this.category,
    required this.message,
    required this.estimatedMonthlySaving,
  });

  final String category;
  final String message;
  final double estimatedMonthlySaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.neonEmerald.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.neonEmerald.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.trending_down,
            color: AppTheme.neonEmerald,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$category · save ~${formatMoney(estimatedMonthlySaving)}/mo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
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
    required this.cashFlowForecast,
    required this.spendCutSuggestions,
    required this.spendCutContext,
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
  final _CashFlowForecast cashFlowForecast;
  final List<SpendCutSuggestion> spendCutSuggestions;
  final SpendCutContext spendCutContext;
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
      transactions: snapshot.transactions,
      thisMonthExpense: thisMonthExpense,
      currentBalance: snapshot.totalBalance,
      outstandingDebt: snapshot.totalToPay,
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
    final cashFlowForecast = _calculateCashFlowForecast(
      transactions: snapshot.transactions,
      currentBalance: snapshot.totalBalance,
    );
    final spendCutSuggestions = suggestSpendingCuts(
      transactions: snapshot.transactions,
    );
    final spendCutContext = summarizeSpendCutContext(
      transactions: snapshot.transactions,
    );

    return _AnalyticsData(
      health: health,
      cashFlowForecast: cashFlowForecast,
      spendCutSuggestions: spendCutSuggestions,
      spendCutContext: spendCutContext,
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
    required this.hasEnoughData,
    required this.grade,
    required this.message,
    required this.savingsRate,
    required this.budgetAdherence,
    required this.spendingConsistency,
    required this.incomeStability,
    required this.financialCushion,
  });

  final int overall;
  final bool hasEnoughData;
  final String grade;
  final String message;
  final _HealthMetric savingsRate;
  final _HealthMetric budgetAdherence;
  final _HealthMetric spendingConsistency;
  final _HealthMetric incomeStability;
  final _HealthMetric financialCushion;
}

class _HealthMetric {
  const _HealthMetric({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.icon,
    required this.color,
    this.insufficientData = false,
  });

  final String label;
  final int score;
  final int maxScore;
  final String status;
  final IconData icon;
  final Color color;
  final bool insufficientData;
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

/// Outstanding money you owe other people (borrow/repay), netted per person
/// so an overpayment to one person can't offset debt owed to a different
/// one. Already computed correctly by [DashboardSnapshot.totalToPay].
///
/// Mirrors calculateFinancialHealth in the web app's lib/smart-insights.ts.
/// Savings rate, spending consistency, and income stability compare a
/// trailing 30-day window against the 30 days before it rather than the
/// current calendar month against last calendar month, since a strict
/// calendar comparison badly distorts the score early in the month (e.g.
/// rent paid on day 1 before salary lands looks like a spending crisis).
/// Budget adherence stays calendar-month based since budgets are inherently
/// monthly. Any metric that can't be measured yet is excluded from the
/// overall score rather than silently defaulting to a mid-range value.
_HealthScore _calculateHealth({
  required List<TransactionRecord> transactions,
  required double thisMonthExpense,
  required double currentBalance,
  required double outstandingDebt,
  required List<Budget> budgets,
  required List<_CategorySpend> categoryRows,
}) {
  final now = DateTime.now();
  final periodStart = now.subtract(const Duration(days: 30));
  final priorPeriodStart = now.subtract(const Duration(days: 60));

  final periodTx = transactions.where((transaction) {
    final date = transaction.displayDate;
    return !date.isBefore(periodStart) && !date.isAfter(now);
  });
  final priorPeriodTx = transactions.where((transaction) {
    final date = transaction.displayDate;
    return !date.isBefore(priorPeriodStart) && date.isBefore(periodStart);
  });

  final periodIncome = _sumType(periodTx.toList(), 'income');
  final periodExpense = _sumType(periodTx.toList(), 'expense');
  final priorPeriodIncome = _sumType(priorPeriodTx.toList(), 'income');
  final priorPeriodExpense = _sumType(priorPeriodTx.toList(), 'expense');

  // 1. Savings Rate (0-25)
  final hasFlowData = periodIncome > 0 || periodExpense > 0;
  final savingsRate = periodIncome > 0
      ? ((periodIncome - periodExpense) / periodIncome) * 100
      : 0.0;
  final savingsScore = !hasFlowData
      ? 0
      : savingsRate >= 30
      ? 25
      : savingsRate >= 20
      ? 21
      : savingsRate >= 10
      ? 17
      : savingsRate >= 0
      ? 12
      : 4;
  final savingsLabel = !hasFlowData
      ? 'Not enough data'
      : savingsRate >= 30
      ? 'Excellent'
      : savingsRate >= 20
      ? 'Great'
      : savingsRate >= 10
      ? 'Good'
      : savingsRate >= 0
      ? 'Fair'
      : 'Needs attention';

  // 2. Budget Adherence (0-20), calendar-month based since budgets are monthly.
  var budgetScore = 12; // Default if no budgets (60% of max, same as before)
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
    budgetScore = ((budgetValue / 100) * 20).round();
    budgetLabel = budgetValue >= 90
        ? 'Excellent'
        : budgetValue >= 70
        ? 'Good'
        : budgetValue >= 50
        ? 'Fair'
        : 'Over budget';

    // Per-category adherence can look "Excellent" while overall spending
    // still blows past the total budget through unbudgeted categories -
    // dock points when that happens instead of missing it entirely.
    final totalBudgetCap = budgets.fold(0.0, (sum, b) => sum + b.amount);
    if (totalBudgetCap > 0 && thisMonthExpense > totalBudgetCap * 1.2) {
      budgetScore = (budgetScore * 0.6).round();
      budgetLabel = 'Overspending outside budgets';
    }
  }

  // 3. Spending Consistency (0-20)
  final hasConsistencyData = priorPeriodExpense > 0;
  final expenseChange = hasConsistencyData
      ? ((periodExpense - priorPeriodExpense).abs() / priorPeriodExpense) * 100
      : 0.0;
  final consistencyScore = !hasConsistencyData
      ? 0
      : expenseChange <= 10
      ? 20
      : expenseChange <= 20
      ? 16
      : expenseChange <= 30
      ? 12
      : expenseChange <= 50
      ? 8
      : 4;
  final consistencyLabel = !hasConsistencyData
      ? 'Not enough data'
      : expenseChange <= 10
      ? 'Very stable'
      : expenseChange <= 20
      ? 'Stable'
      : expenseChange <= 30
      ? 'Moderate'
      : expenseChange <= 50
      ? 'Variable'
      : 'Volatile';

  // 4. Income Stability (0-15)
  final hasIncomeStabilityData = priorPeriodIncome > 0;
  final incomeChange = hasIncomeStabilityData
      ? ((periodIncome - priorPeriodIncome).abs() / priorPeriodIncome) * 100
      : 0.0;
  final incomeScore = !hasIncomeStabilityData
      ? 0
      : incomeChange <= 5
      ? 15
      : incomeChange <= 15
      ? 11
      : incomeChange <= 30
      ? 7
      : 4;
  final incomeLabel = !hasIncomeStabilityData
      ? 'Not enough data'
      : incomeChange <= 5
      ? 'Very stable'
      : incomeChange <= 15
      ? 'Stable'
      : incomeChange <= 30
      ? 'Moderate'
      : 'Variable';

  // 5. Financial Cushion (0-20) - months of expenses covered by current
  // balance minus outstanding debt owed to other people.
  final netLiquidPosition = currentBalance - outstandingDebt;
  final avgDailyExpense = periodExpense / 30;

  int cushionScore;
  String cushionLabel;
  double cushionDays;
  if (avgDailyExpense <= 0) {
    cushionDays = netLiquidPosition > 0 ? double.infinity : 0;
    cushionScore = netLiquidPosition > 0 ? 20 : 4;
    cushionLabel = netLiquidPosition > 0 ? 'Excellent' : 'Needs attention';
  } else {
    cushionDays = netLiquidPosition / avgDailyExpense;
    if (netLiquidPosition <= 0) {
      cushionScore = 0;
      cushionLabel = 'In the red';
    } else if (cushionDays >= 90) {
      cushionScore = 20;
      cushionLabel = 'Excellent';
    } else if (cushionDays >= 60) {
      cushionScore = 16;
      cushionLabel = 'Great';
    } else if (cushionDays >= 30) {
      cushionScore = 12;
      cushionLabel = 'Good';
    } else if (cushionDays >= 14) {
      cushionScore = 8;
      cushionLabel = 'Fair';
    } else {
      cushionScore = 4;
      cushionLabel = 'Needs attention';
    }
  }

  // Normalize across only the metrics that had enough data to measure, so
  // a new account isn't penalized (or flattered) by metrics that are
  // really just "unknown".
  final metrics = [
    (score: savingsScore, max: 25, insufficient: !hasFlowData),
    (score: budgetScore, max: 20, insufficient: false),
    (score: consistencyScore, max: 20, insufficient: !hasConsistencyData),
    (score: incomeScore, max: 15, insufficient: !hasIncomeStabilityData),
    (score: cushionScore, max: 20, insufficient: false),
  ];
  final available = metrics.where((m) => !m.insufficient).toList();
  final availableMax = available.fold(0, (sum, m) => sum + m.max);
  final overall = availableMax > 0
      ? ((available.fold(0, (sum, m) => sum + m.score) / availableMax) * 100)
            .round()
      : 0;
  // Budget adherence (defaults when no budgets are set) and financial
  // cushion (computable from balance alone, even at 0) can both look
  // "available" without a single real transaction ever happening - require
  // at least one metric actually derived from transaction history too, or
  // a brand-new account gets a confident-looking grade from nothing.
  final hasRealFlowData =
      hasFlowData || hasConsistencyData || hasIncomeStabilityData;
  final hasEnoughData = hasRealFlowData && available.length >= 2;

  final grade = !hasEnoughData
      ? 'F'
      : overall >= 85
      ? 'A'
      : overall >= 70
      ? 'B'
      : overall >= 55
      ? 'C'
      : overall >= 40
      ? 'D'
      : 'F';
  final message = !hasEnoughData
      ? 'Add a few weeks of transactions to unlock a meaningful score.'
      : overall >= 85
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
    hasEnoughData: hasEnoughData,
    grade: grade,
    message: message,
    savingsRate: _HealthMetric(
      label: 'Savings Rate',
      score: savingsScore,
      maxScore: 25,
      status: savingsLabel,
      icon: Icons.savings_outlined,
      color: AppTheme.neonEmerald,
      insufficientData: !hasFlowData,
    ),
    budgetAdherence: _HealthMetric(
      label: 'Budget Adherence',
      score: budgetScore,
      maxScore: 20,
      status: budgetLabel,
      icon: Icons.track_changes,
      color: AppTheme.neonCyan,
    ),
    spendingConsistency: _HealthMetric(
      label: 'Spending Consistency',
      score: consistencyScore,
      maxScore: 20,
      status: consistencyLabel,
      icon: Icons.timeline,
      color: AppTheme.neonRose,
      insufficientData: !hasConsistencyData,
    ),
    incomeStability: _HealthMetric(
      label: 'Income Stability',
      score: incomeScore,
      maxScore: 15,
      status: incomeLabel,
      icon: Icons.trending_up,
      color: AppTheme.neonAmber,
      insufficientData: !hasIncomeStabilityData,
    ),
    financialCushion: _HealthMetric(
      label: 'Financial Cushion',
      score: cushionScore,
      maxScore: 20,
      status: cushionLabel,
      icon: Icons.shield_outlined,
      color: AppTheme.neonCyan,
    ),
  );
}

enum _ForecastStatus { insufficientData, growing, stable, declining, critical }

class _CashFlowForecast {
  const _CashFlowForecast({
    required this.status,
    required this.currentBalance,
    required this.avgDailyNetChange,
    required this.daysOfHistory,
    required this.projectedDate,
    required this.daysRemaining,
    required this.message,
  });

  final _ForecastStatus status;
  final double currentBalance;
  final double avgDailyNetChange;
  final int daysOfHistory;
  final DateTime? projectedDate;
  final int? daysRemaining;
  final String message;
}

const _forecastWindowDays = 30;
const _forecastMinHistoryDays = 7;

/// Projects when the total balance will run out (or how it'll grow) based on
/// the trailing net daily cash flow across all accounts. Transfers between
/// own accounts net to zero automatically since both the credit and debit
/// side of the same transaction are included in the same sum. Mirrors
/// calculateCashFlowForecast in the web app's lib/smart-insights.ts.
_CashFlowForecast _calculateCashFlowForecast({
  required List<TransactionRecord> transactions,
  required double currentBalance,
}) {
  final now = DateTime.now();
  final windowStart = now.subtract(const Duration(days: _forecastWindowDays));

  DateTime? earliest;
  for (final transaction in transactions) {
    final date = transaction.displayDate;
    if (earliest == null || date.isBefore(earliest)) earliest = date;
  }

  final daysOfHistory = earliest == null
      ? 0
      : now.difference(earliest).inDays.clamp(0, _forecastWindowDays);

  if (daysOfHistory < _forecastMinHistoryDays) {
    return _CashFlowForecast(
      status: _ForecastStatus.insufficientData,
      currentBalance: currentBalance,
      avgDailyNetChange: 0,
      daysOfHistory: daysOfHistory,
      projectedDate: null,
      daysRemaining: null,
      message:
          'Keep logging transactions — we need at least a week of history '
          'to forecast your cash flow.',
    );
  }

  var netChange = 0.0;
  for (final transaction in transactions) {
    final date = transaction.displayDate;
    if (date.isBefore(windowStart) || date.isAfter(now)) continue;
    if (transaction.toAccountId != null) netChange += transaction.amount;
    if (transaction.fromAccountId != null) netChange -= transaction.amount;
  }

  final avgDailyNetChange = netChange / daysOfHistory;

  if (avgDailyNetChange >= 0) {
    final projectedGrowth = avgDailyNetChange * 30;
    return _CashFlowForecast(
      status: avgDailyNetChange == 0
          ? _ForecastStatus.stable
          : _ForecastStatus.growing,
      currentBalance: currentBalance,
      avgDailyNetChange: avgDailyNetChange,
      daysOfHistory: daysOfHistory,
      projectedDate: null,
      daysRemaining: null,
      message: avgDailyNetChange == 0
          ? 'Your balance has held steady recently — income and spending '
                'are roughly matched.'
          : 'At this pace, your balance is on track to grow by '
                '~${formatMoney(projectedGrowth)} over the next 30 days.',
    );
  }

  final burnRate = -avgDailyNetChange;
  if (currentBalance <= 0) {
    return _CashFlowForecast(
      status: _ForecastStatus.critical,
      currentBalance: currentBalance,
      avgDailyNetChange: avgDailyNetChange,
      daysOfHistory: daysOfHistory,
      projectedDate: null,
      daysRemaining: 0,
      message:
          'Your balance is already at or below zero, and recent spending '
          'is outpacing income.',
    );
  }

  final daysRemaining = (currentBalance / burnRate).floor();
  final projectedDate = now.add(Duration(days: daysRemaining));

  if (daysRemaining > 180) {
    return _CashFlowForecast(
      status: _ForecastStatus.declining,
      currentBalance: currentBalance,
      avgDailyNetChange: avgDailyNetChange,
      daysOfHistory: daysOfHistory,
      projectedDate: projectedDate,
      daysRemaining: daysRemaining,
      message:
          'Spending is outpacing income slightly, but at this rate you '
          'have more than 6 months of runway — worth watching, not urgent.',
    );
  }

  return _CashFlowForecast(
    status: daysRemaining <= 14
        ? _ForecastStatus.critical
        : _ForecastStatus.declining,
    currentBalance: currentBalance,
    avgDailyNetChange: avgDailyNetChange,
    daysOfHistory: daysOfHistory,
    projectedDate: projectedDate,
    daysRemaining: daysRemaining,
    message:
        'At this rate, you will run low by ${formatShortDate(projectedDate)} '
        '(about $daysRemaining day${daysRemaining == 1 ? '' : 's'}) if '
        'nothing changes.',
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
