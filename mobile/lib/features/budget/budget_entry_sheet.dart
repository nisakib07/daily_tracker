import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../data/budget_advisor.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_form_page.dart';

const _defaultBudgetCategories = [
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Entertainment',
  'Health',
  'Education',
  'Rent',
  'Charity',
  'Personal_Care',
  'Other Expense',
];

Future<bool?> showBudgetEntrySheet({
  required BuildContext context,
  required DateTime month,
  required List<String> categories,
  required Map<String, double> existingBudgets,
  required List<TransactionRecord> transactions,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => BudgetEntrySheet(
        month: month,
        categories: categories,
        existingBudgets: existingBudgets,
        transactions: transactions,
        dataSource: dataSource,
      ),
    ),
  );
}

class BudgetEntrySheet extends StatefulWidget {
  const BudgetEntrySheet({
    super.key,
    required this.month,
    required this.categories,
    required this.existingBudgets,
    required this.transactions,
    this.dataSource,
  });

  final DateTime month;
  final List<String> categories;
  final Map<String, double> existingBudgets;
  final List<TransactionRecord> transactions;
  final MoneyDataSource? dataSource;

  @override
  State<BudgetEntrySheet> createState() => _BudgetEntrySheetState();
}

class _BudgetEntrySheetState extends State<BudgetEntrySheet> {
  final _newCategoryController = TextEditingController();
  final _controllers = <String, TextEditingController>{};
  late List<String> _categories;
  bool _isSaving = false;
  bool _isSuggesting = false;
  String? _error;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    final set = <String>{
      ..._defaultBudgetCategories,
      ...widget.categories.where((category) => category.trim().isNotEmpty),
      ...widget.existingBudgets.keys,
      'Uncategorized',
    };
    _categories = set.toList()..sort((a, b) => a.compareTo(b));
    for (final category in _categories) {
      _controllers[category] = TextEditingController(
        text: _initialText(widget.existingBudgets[category]),
      );
    }
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCategory() {
    final category = _newCategoryController.text.trim();
    if (category.isEmpty) return;

    final exists = _controllers.keys.any(
      (item) => item.toLowerCase() == category.toLowerCase(),
    );
    if (exists) {
      setState(() => _categoryError = 'This category already exists.');
      return;
    }

    setState(() {
      _categories = [..._categories, category]..sort((a, b) => a.compareTo(b));
      _controllers[category] = TextEditingController();
      _newCategoryController.clear();
      _categoryError = null;
    });
  }

  Future<void> _suggestBudgets() async {
    final history = summarizeBudgetHistory(transactions: widget.transactions);
    if (!history.hasEnoughData) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(history.insufficientDataMessage)));
      return;
    }

    setState(() => _isSuggesting = true);

    final suggestion = suggestBudgets(transactions: widget.transactions);
    final summary = suggestion.summary;
    final amounts = suggestion.amounts;

    if (!mounted) return;
    setState(() {
      _isSuggesting = false;
      for (final entry in amounts.entries) {
        final controller = _controllers.putIfAbsent(entry.key, () {
          _categories = [..._categories, entry.key]
            ..sort((a, b) => a.compareTo(b));
          return TextEditingController();
        });
        controller.text = _initialText(entry.value);
      }
      _error = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(summary)));
  }

  double get _plannedTotal {
    return _controllers.values.fold(0, (total, controller) {
      final amount = double.tryParse(controller.text.trim());
      return total + (amount != null && amount > 0 ? amount : 0);
    });
  }

  int get _budgetedCategoryCount {
    return _controllers.values.where((controller) {
      final amount = double.tryParse(controller.text.trim());
      return amount != null && amount > 0;
    }).length;
  }

  void _amountChanged() {
    setState(() => _error = null);
  }

  Future<void> _save() async {
    final values = <String, double>{};

    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final amount = double.tryParse(text);
      if (amount == null || amount < 0) {
        setState(() => _error = 'Check the amount for ${entry.key}.');
        return;
      }
      values[entry.key] = amount;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .replaceBudgetsForMonth(month: widget.month, budgets: values);

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not save budgets. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearMonth() async {
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Clear Month Budgets?',
      message:
          'Remove every category budget for ${formatMonth(widget.month)}? This cannot be undone.',
      confirmLabel: 'Clear Budgets',
      icon: Icons.delete_sweep_outlined,
    );

    if (!mounted || !confirmed) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .clearBudgetsForMonth(widget.month);

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not clear budgets. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Set Budgets',
      accent: AppTheme.neonCyan,
      actions: [
        IconButton(
          key: const ValueKey('budget-suggest'),
          tooltip: 'Suggest budgets from my history',
          onPressed: (_isSaving || _isSuggesting) ? null : _suggestBudgets,
          icon: _isSuggesting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.neonAmber,
                  ),
                )
              : const Icon(Icons.lightbulb_outline, color: AppTheme.neonAmber),
        ),
        if (widget.existingBudgets.isNotEmpty)
          IconButton(
            key: const ValueKey('budget-clear-month'),
            tooltip: 'Clear month budgets',
            onPressed: (_isSaving || _isSuggesting) ? null : _clearMonth,
            icon: const Icon(Icons.delete_outline, color: AppTheme.neonRose),
          ),
        const SizedBox(width: 4),
      ],
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('budget-form-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: appFormContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFormHeader(
                    title: 'Monthly plan',
                    subtitle: formatMonth(widget.month),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.neonCyan,
                  ),
                  const SizedBox(height: 18),
                  _BudgetPlanSummary(
                    total: _plannedTotal,
                    categoryCount: _budgetedCategoryCount,
                  ),
                  const SizedBox(height: 22),
                  const _BudgetSectionTitle(
                    title: 'Add a category',
                    icon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('budget-new-category'),
                          controller: _newCategoryController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'New category',
                            prefixIcon: const Icon(Icons.sell_outlined),
                            errorText: _categoryError,
                          ),
                          onChanged: (_) {
                            setState(() => _categoryError = null);
                          },
                          onSubmitted: (_) => _addCategory(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        key: const ValueKey('budget-add-category'),
                        tooltip: 'Add category',
                        onPressed: _newCategoryController.text.trim().isEmpty
                            ? null
                            : _addCategory,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _BudgetSectionTitle(
                    title: 'Category limits',
                    icon: Icons.tune,
                    trailing: '${_categories.length}',
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 520;
                      final itemWidth = twoColumns
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        key: const ValueKey('budget-category-grid'),
                        spacing: 10,
                        runSpacing: 10,
                        children: _categories.map((category) {
                          return SizedBox(
                            width: itemWidth,
                            child: _BudgetAmountRow(
                              category: category,
                              controller: _controllers[category]!,
                              onChanged: _amountChanged,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _BudgetError(message: _error!),
                  ],
                ],
              ),
            ),
          ),
          AppFormActionBar(
            accent: AppTheme.neonCyan,
            saveLabel: 'Save Budgets',
            isSaving: _isSaving || _isSuggesting,
            onCancel: () => Navigator.of(context).pop(false),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

class _BudgetAmountRow extends StatelessWidget {
  const _BudgetAmountRow({
    required this.category,
    required this.controller,
    required this.onChanged,
  });

  final String category;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('budget-amount-$category'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: _displayCategory(category),
        hintText: 'No limit',
        prefixText: '\u09F3 ',
        prefixIcon: Icon(_categoryIcon(category)),
      ),
    );
  }
}

class _BudgetPlanSummary extends StatelessWidget {
  const _BudgetPlanSummary({required this.total, required this.categoryCount});

  final double total;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('budget-total-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neonCyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planned this month',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoney(total),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.neonCyan,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: AppTheme.neonCyan.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$categoryCount',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  categoryCount == 1 ? 'category' : 'categories',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _BudgetSectionTitle extends StatelessWidget {
  const _BudgetSectionTitle({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.neonCyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (trailing != null)
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              trailing!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _BudgetError extends StatelessWidget {
  const _BudgetError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayCategory(String category) {
  return category.replaceAll('_', ' ');
}

IconData _categoryIcon(String category) {
  return switch (category.toLowerCase()) {
    'food' => Icons.restaurant_outlined,
    'transport' => Icons.directions_bus_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'bills' => Icons.receipt_long_outlined,
    'entertainment' => Icons.movie_outlined,
    'health' => Icons.health_and_safety_outlined,
    'education' => Icons.school_outlined,
    'rent' => Icons.home_work_outlined,
    'charity' => Icons.volunteer_activism_outlined,
    'personal_care' => Icons.spa_outlined,
    'uncategorized' => Icons.category_outlined,
    _ => Icons.sell_outlined,
  };
}

String _initialText(double? value) {
  if (value == null || value <= 0) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}
