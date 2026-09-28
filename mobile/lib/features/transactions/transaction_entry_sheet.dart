import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/category_store.dart';
import '../../core/amount_input.dart';
import '../../core/date_times.dart';
import '../../core/error_messages.dart';
import '../../core/formatters.dart';
import '../../core/mimi_time.dart';
import '../../data/money_repository.dart';
import '../../data/quick_add_shortcut_store.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

enum TransactionEntryKind { income, expense, transfer }

const _quickAddShortcutColors = [
  AppTheme.neonAmber,
  AppTheme.neonCyan,
  AppTheme.neonRose,
  AppTheme.teal,
  AppTheme.neonEmerald,
  AppTheme.neonViolet,
];

Future<bool?> showTransactionEntrySheet({
  required BuildContext context,
  required TransactionEntryKind kind,
  required List<AccountBalance> accounts,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) {
        return TransactionEntrySheet(
          kind: kind,
          accounts: accounts,
          dataSource: dataSource,
        );
      },
    ),
  );
}

Future<bool?> showEditTransactionSheet({
  required BuildContext context,
  required TransactionRecord transaction,
  required List<AccountBalance> accounts,
  required List<Person> people,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) {
        return EditTransactionSheet(
          transaction: transaction,
          accounts: accounts,
          people: people,
          dataSource: dataSource,
        );
      },
    ),
  );
}

class TransactionEntrySheet extends StatefulWidget {
  const TransactionEntrySheet({
    super.key,
    required this.kind,
    required this.accounts,
    this.dataSource,
  });

  final TransactionEntryKind kind;
  final List<AccountBalance> accounts;
  final MoneyDataSource? dataSource;

  @override
  State<TransactionEntrySheet> createState() => _TransactionEntrySheetState();
}

class _TransactionEntrySheetState extends State<TransactionEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _primaryAccountId;
  String? _toAccountId;
  String? _category;
  List<String> _categories = const [];
  List<QuickAddShortcut> _quickAddShortcuts = const [];
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

  bool get _isIncome => widget.kind == TransactionEntryKind.income;
  bool get _isExpense => widget.kind == TransactionEntryKind.expense;
  bool get _isTransfer => widget.kind == TransactionEntryKind.transfer;

  Color get _accent {
    if (_isIncome) return AppTheme.neonEmerald;
    if (_isExpense) return AppTheme.neonRose;
    return AppTheme.neonCyan;
  }

  IconData get _heroIcon {
    if (_isIncome) return Icons.south_west;
    if (_isExpense) return Icons.north_east;
    return Icons.swap_horiz;
  }

  String get _title {
    if (_isIncome) return 'Add Income';
    if (_isExpense) return 'Add Expense';
    return 'Transfer';
  }

  String get _accountLabel {
    if (_isIncome) return 'To account';
    if (_isExpense) return 'From account';
    return 'From account';
  }

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _primaryAccountId = widget.accounts.first.account.id;
      if (_isTransfer && widget.accounts.length > 1) {
        _toAccountId = widget.accounts[1].account.id;
      }
    }
    if (!_isTransfer) {
      _categories = _defaultCategories;
      _category = _categories.first;
      _loadCategories();
    }
    if (_isExpense) {
      _loadQuickAddShortcuts();
    }
    MimiTime.instance.enabled.addListener(_onMimiTimeChanged);
  }

  @override
  void dispose() {
    MimiTime.instance.enabled.removeListener(_onMimiTimeChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onMimiTimeChanged() {
    if (mounted) setState(() {});
  }

  /// Whether this expense will be saved under Mimi (see MimiTime).
  bool get _mimiTime => _isExpense && MimiTime.instance.isOn;

  List<String> get _defaultCategories {
    if (_isIncome) return defaultIncomeCategories;
    if (_isExpense) return defaultExpenseCategories;
    return const [];
  }

  Future<void> _loadCategories() async {
    final kind = _isIncome ? CategoryKind.income : CategoryKind.expense;
    final categories = await CategoryStore().loadMerged(kind);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _category ??= categories.isEmpty ? null : categories.first;
    });
  }

  Future<void> _loadQuickAddShortcuts() async {
    final shortcuts = await QuickAddShortcutStore().load();
    if (!mounted) return;
    setState(() => _quickAddShortcuts = shortcuts);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = parseAmount(_amountController.text)!;
    final occurredAt = _dateWithCurrentTime(_selectedDate);
    final repository =
        widget.dataSource ?? MoneyRepository(Supabase.instance.client);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_isIncome) {
        await repository.createMoneyIn(
          amount: amount,
          accountId: _primaryAccountId!,
          category: _category!,
          occurredAt: occurredAt,
          note: _noteController.text,
        );
      } else if (_isExpense) {
        final saved = _mimiTime
            ? MimiTime.apply(category: _category!, note: _noteController.text)
            : (category: _category!, note: _noteController.text);
        await repository.createMoneyOut(
          amount: amount,
          accountId: _primaryAccountId!,
          category: saved.category,
          occurredAt: occurredAt,
          note: saved.note,
        );
      } else {
        await repository.createTransfer(
          amount: amount,
          fromAccountId: _primaryAccountId!,
          toAccountId: _toAccountId!,
          occurredAt: occurredAt,
          note: _noteController.text,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not save. ${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final range = pickableDateRange(_selectedDate);
    final next = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: range.first,
      lastDate: range.last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent),
          ),
          child: child!,
        );
      },
    );

    if (next != null) {
      setState(() => _selectedDate = next);
    }
  }

  void _applyShortcut(QuickAddShortcut shortcut) {
    setState(() {
      if (_categories.contains(shortcut.category)) {
        _category = shortcut.category;
      }
      _noteController.text = shortcut.subCategory;
      _amountController.text = shortcut.amount == null
          ? ''
          : _amountText(shortcut.amount!);

      if (widget.accounts.any(
        (item) => item.account.id == shortcut.accountId,
      )) {
        _primaryAccountId = shortcut.accountId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        widget.accounts.isNotEmpty &&
        (!_isTransfer || widget.accounts.length > 1);

    return AppFormPage(
      title: _title,
      accent: _accent,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: appFormContentPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormHeader(
                      title: _title,
                      subtitle: DateFormat(
                        'EEEE, MMM d',
                      ).format(DateTime.now()),
                      icon: _heroIcon,
                      color: _accent,
                    ),
                    const SizedBox(height: 18),
                    _AmountField(controller: _amountController, color: _accent),
                    const SizedBox(height: 16),
                    if (widget.accounts.isEmpty)
                      const _NoAccountsNotice()
                    else ...[
                      _AccountDropdown(
                        label: _accountLabel,
                        value: _primaryAccountId,
                        accounts: widget.accounts,
                        color: _accent,
                        disabledAccountId: _toAccountId,
                        onChanged: (value) {
                          setState(() => _primaryAccountId = value);
                        },
                      ),
                      if (_isTransfer) ...[
                        const SizedBox(height: 12),
                        if (widget.accounts.length < 2)
                          const _TransferNeedsTwoAccountsNotice()
                        else ...[
                          _TransferPath(
                            from: _accountName(_primaryAccountId),
                            to: _accountName(_toAccountId),
                          ),
                          const SizedBox(height: 12),
                          _AccountDropdown(
                            label: 'To account',
                            value: _toAccountId,
                            accounts: widget.accounts,
                            color: _accent,
                            disabledAccountId: _primaryAccountId,
                            onChanged: (value) {
                              setState(() => _toAccountId = value);
                            },
                          ),
                        ],
                      ],
                      if (!_isTransfer) ...[
                        if (_isExpense && _quickAddShortcuts.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _QuickAddShortcuts(
                            shortcuts: _quickAddShortcuts,
                            onSelect: _applyShortcut,
                          ),
                        ],
                        if (_mimiTime) ...[
                          const SizedBox(height: 12),
                          const AppInlineNotice(
                            key: ValueKey('mimi-time-notice'),
                            icon: Icons.favorite_outline,
                            message:
                                'Mimi time is on, so this expense is saved '
                                'under Mimi. What it was for goes at the '
                                'start of its note.',
                            color: AppTheme.neonViolet,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _CategoryDropdown(
                          value: _category,
                          categories: _categories,
                          label: _mimiTime ? 'What for' : 'Category',
                          onChanged: (value) {
                            setState(() => _category = value);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      _DateButton(
                        date: _selectedDate,
                        color: _accent,
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          hintText: 'Optional',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AppInlineNotice(
                        icon: Icons.error_outline,
                        message: _error!,
                        color: AppTheme.neonRose,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AppFormActionBar(
              accent: _accent,
              saveLabel: _title,
              isSaving: _isSaving,
              canSave: canSave,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _accountName(String? accountId) {
    if (accountId == null) return null;
    for (final item in widget.accounts) {
      if (item.account.id == accountId) return item.account.name;
    }
    return null;
  }
}

class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.people,
    this.dataSource,
  });

  final TransactionRecord transaction;
  final List<AccountBalance> accounts;
  final List<Person> people;
  final MoneyDataSource? dataSource;

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _accountId;
  String? _toAccountId;
  String? _personId;
  String? _category;
  List<String> _categories = const [];
  late DateTime _selectedDate;
  bool _isSaving = false;
  String? _error;

  TransactionRecord get _transaction => widget.transaction;
  bool get _isTransfer => _transaction.type == 'transfer';
  bool get _isLoanRelated {
    return const {
      'lend',
      'borrow',
      'repay',
      'receive',
    }.contains(_transaction.type);
  }

  bool get _isInvestmentRelated {
    return const {'invest', 'invest_return'}.contains(_transaction.type);
  }

  bool get _showCategory {
    return !_isTransfer && !_isLoanRelated && !_isInvestmentRelated;
  }

  bool get _showPerson {
    return _isLoanRelated || (!_isTransfer && !_isInvestmentRelated);
  }

  Color get _accent {
    if (_isTransfer) return AppTheme.neonCyan;
    if (_transaction.isIncomeLike) return AppTheme.neonEmerald;
    return AppTheme.neonRose;
  }

  IconData get _heroIcon {
    return switch (_transaction.type) {
      'income' => Icons.south_west,
      'expense' => Icons.north_east,
      'transfer' => Icons.swap_horiz,
      'lend' => Icons.person_remove_alt_1,
      'borrow' => Icons.person_add_alt_1,
      'repay' => Icons.call_made,
      'receive' => Icons.call_received,
      'invest' => Icons.trending_up,
      'invest_return' => Icons.savings_outlined,
      _ => Icons.receipt_long,
    };
  }

  String get _typeLabel {
    return switch (_transaction.type) {
      'income' => 'Income',
      'expense' => 'Expense',
      'transfer' => 'Transfer',
      'lend' => 'Loan Given',
      'borrow' => 'Borrowed',
      'repay' => 'Loan Repaid',
      'receive' => 'Loan Received',
      'invest' => 'Investment',
      'invest_return' => 'Investment Return',
      _ => 'Transaction',
    };
  }

  String get _accountLabel {
    if (_isTransfer) return 'From account';
    if (_transaction.isIncomeLike) return 'To account';
    return 'From account';
  }

  @override
  void initState() {
    super.initState();
    _amountController.text = _amountText(_transaction.amount);
    _noteController.text = _transaction.note ?? '';
    _selectedDate = _transaction.displayDate;
    _accountId = _initialAccountId();
    _toAccountId = _transaction.toAccountId;
    _personId = _transaction.personId;

    if (!_hasAccount(_accountId)) {
      _accountId = widget.accounts.isEmpty
          ? null
          : widget.accounts.first.account.id;
    }

    if (_isTransfer) {
      if (!_hasAccount(_toAccountId) || _toAccountId == _accountId) {
        _toAccountId = _firstAccountExcept(_accountId);
      }
    } else {
      _toAccountId = null;
    }

    if (!_hasPerson(_personId)) {
      _personId = null;
    }

    if (_showCategory) {
      _category = _transaction.category ?? _defaultCategory();
      _categories = _withCurrentCategory(_defaultCategoryList);
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _defaultCategoryList {
    if (_transaction.isIncomeLike) return defaultIncomeCategories;
    if (_transaction.isExpenseLike) return defaultExpenseCategories;
    return const [];
  }

  // The transaction's saved category may be a legacy/custom value that
  // isn't in the default or merged list; the dropdown requires its value
  // to be one of its items, so make sure it's always included.
  List<String> _withCurrentCategory(List<String> categories) {
    if (_category == null || categories.contains(_category)) {
      return categories;
    }
    return [_category!, ...categories];
  }

  Future<void> _loadCategories() async {
    final kind = _transaction.isIncomeLike
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories = await CategoryStore().loadMerged(kind);
    if (!mounted) return;
    setState(() => _categories = _withCurrentCategory(categories));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isTransfer && _accountId == _toAccountId) {
      setState(() => _error = 'Choose two different accounts for a transfer.');
      return;
    }
    if (_isLoanRelated && (_personId == null || _personId!.isEmpty)) {
      setState(() => _error = 'Select a person for this loan entry.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .updateTransaction(
            transaction: _transaction,
            amount: parseAmount(_amountController.text)!,
            accountId: _accountId!,
            toAccountId: _isTransfer ? _toAccountId : null,
            personId: _showPerson ? _personId : _transaction.personId,
            category: _showCategory ? _category : _transaction.category,
            note: _noteController.text,
            occurredAt: _dateWithOriginalTime(
              _selectedDate,
              _transaction.occurredAt,
            ),
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () => _error = 'Could not save changes. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final range = pickableDateRange(_selectedDate);
    final next = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: range.first,
      lastDate: range.last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent),
          ),
          child: child!,
        );
      },
    );

    if (next != null) {
      setState(() => _selectedDate = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        widget.accounts.isNotEmpty &&
        (!_isTransfer || widget.accounts.length > 1) &&
        (!_isLoanRelated || widget.people.isNotEmpty);

    return AppFormPage(
      title: 'Edit Transaction',
      accent: _accent,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: appFormContentPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormHeader(
                      title: 'Edit Transaction',
                      subtitle: DateFormat(
                        'EEEE, MMM d',
                      ).format(DateTime.now()),
                      icon: _heroIcon,
                      color: _accent,
                    ),
                    const SizedBox(height: 12),
                    _TypePill(
                      label: _typeLabel,
                      icon: _heroIcon,
                      color: _accent,
                    ),
                    const SizedBox(height: 18),
                    _AmountField(controller: _amountController, color: _accent),
                    const SizedBox(height: 16),
                    if (widget.accounts.isEmpty)
                      const _NoAccountsNotice()
                    else ...[
                      _AccountDropdown(
                        label: _accountLabel,
                        value: _accountId,
                        accounts: widget.accounts,
                        color: _accent,
                        disabledAccountId: _isTransfer ? _toAccountId : null,
                        onChanged: (value) {
                          setState(() => _accountId = value);
                        },
                      ),
                      if (_isTransfer) ...[
                        const SizedBox(height: 12),
                        _TransferPath(
                          from: _accountName(_accountId),
                          to: _accountName(_toAccountId),
                        ),
                        const SizedBox(height: 12),
                        _AccountDropdown(
                          label: 'To account',
                          value: _toAccountId,
                          accounts: widget.accounts,
                          color: _accent,
                          disabledAccountId: _accountId,
                          onChanged: (value) {
                            setState(() => _toAccountId = value);
                          },
                        ),
                      ],
                      if (_showCategory) ...[
                        const SizedBox(height: 12),
                        _CategoryDropdown(
                          value: _category,
                          categories: _categories,
                          onChanged: (value) {
                            setState(() => _category = value);
                          },
                        ),
                      ],
                      if (_showPerson) ...[
                        const SizedBox(height: 12),
                        if (_isLoanRelated && widget.people.isEmpty)
                          const _NoPeopleNotice()
                        else
                          _PersonDropdown(
                            value: _personId,
                            people: widget.people,
                            color: _accent,
                            requiredPerson: _isLoanRelated,
                            onChanged: (value) {
                              setState(() => _personId = value);
                            },
                          ),
                      ],
                      const SizedBox(height: 12),
                      _DateButton(
                        date: _selectedDate,
                        color: _accent,
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          hintText: 'Optional',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AppInlineNotice(
                        icon: Icons.error_outline,
                        message: _error!,
                        color: AppTheme.neonRose,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AppFormActionBar(
              accent: _accent,
              saveLabel: 'Save Changes',
              isSaving: _isSaving,
              canSave: canSave,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _initialAccountId() {
    if (_isTransfer || _transaction.isExpenseLike) {
      return _transaction.fromAccountId ?? _transaction.toAccountId;
    }
    return _transaction.toAccountId ?? _transaction.fromAccountId;
  }

  String _defaultCategory() {
    if (_transaction.isIncomeLike) return defaultIncomeCategories.first;
    if (_transaction.isExpenseLike) return defaultExpenseCategories.first;
    return _typeLabel;
  }

  String? _accountName(String? accountId) {
    if (accountId == null) return null;
    for (final item in widget.accounts) {
      if (item.account.id == accountId) return item.account.name;
    }
    return null;
  }

  bool _hasAccount(String? accountId) {
    return accountId != null &&
        widget.accounts.any((item) => item.account.id == accountId);
  }

  String? _firstAccountExcept(String? accountId) {
    for (final item in widget.accounts) {
      if (item.account.id != accountId) return item.account.id;
    }
    return null;
  }

  bool _hasPerson(String? personId) {
    return personId != null &&
        widget.people.any((person) => person.id == personId);
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.color});

  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final amount = parseAmount(value.text) ?? 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\u09F3 ',
              suffixText: amount > 0 ? formatMoney(amount) : null,
              suffixStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
              filled: true,
            ),
            validator: validateAmount,
          ),
        );
      },
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.color,
    required this.onChanged,
    this.disabledAccountId,
  });

  final String label;
  final String? value;
  final List<AccountBalance> accounts;
  final Color color;
  final ValueChanged<String?> onChanged;
  final String? disabledAccountId;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: color),
      ),
      items: accounts.map((item) {
        final disabled = item.account.id == disabledAccountId;
        return DropdownMenuItem(
          value: item.account.id,
          enabled: !disabled,
          child: Text(
            '${item.account.name}  ${formatMoney(item.balance)}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: disabled
                ? TextStyle(color: Theme.of(context).disabledColor)
                : null,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select an account' : null,
    );
  }
}

class _PersonDropdown extends StatelessWidget {
  const _PersonDropdown({
    required this.value,
    required this.people,
    required this.color,
    required this.requiredPerson,
    required this.onChanged,
  });

  final String? value;
  final List<Person> people;
  final Color color;
  final bool requiredPerson;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: requiredPerson ? value : value ?? '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: requiredPerson ? 'Person' : 'Person',
        helperText: requiredPerson ? null : 'Optional',
        prefixIcon: Icon(Icons.person_outline, color: color),
      ),
      items: [
        if (!requiredPerson)
          const DropdownMenuItem(value: '', child: Text('No person')),
        ...people.map((person) {
          return DropdownMenuItem(
            value: person.id,
            child: Text(person.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) =>
          onChanged(value == null || value.isEmpty ? null : value),
      validator: (value) {
        if (requiredPerson && (value == null || value.isEmpty)) {
          return 'Select a person';
        }
        return null;
      },
    );
  }
}

class _QuickAddShortcuts extends StatelessWidget {
  const _QuickAddShortcuts({required this.shortcuts, required this.onSelect});

  final List<QuickAddShortcut> shortcuts;
  final ValueChanged<QuickAddShortcut> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ADD',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < shortcuts.length; i++)
              _QuickAddChip(
                shortcut: shortcuts[i],
                color:
                    _quickAddShortcutColors[i % _quickAddShortcutColors.length],
                onSelect: onSelect,
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({
    required this.shortcut,
    required this.color,
    required this.onSelect,
  });

  final QuickAddShortcut shortcut;
  final Color color;
  final ValueChanged<QuickAddShortcut> onSelect;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.bolt_outlined, size: 16, color: color),
      label: Text(shortcut.subCategory),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      onPressed: () => onSelect(shortcut),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
    this.label = 'Category',
  });

  final String? value;
  final List<String> categories;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.sell_outlined),
      ),
      items: categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select a category' : null,
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.date,
    required this.color,
    required this.onPressed,
  });

  final DateTime date;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.calendar_today, color: color),
      label: Text(DateFormat('MMM d, yyyy').format(date)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _TransferPath extends StatelessWidget {
  const _TransferPath({required this.from, required this.to});

  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.neonCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              from ?? 'Source',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.arrow_forward,
              color: AppTheme.neonCyan,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(to ?? 'Destination', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _NoAccountsNotice extends StatelessWidget {
  const _NoAccountsNotice();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      icon: Icons.account_balance_wallet_outlined,
      message:
          'No accounts found. Create or restore accounts before adding transactions.',
      color: AppTheme.neonRose,
    );
  }
}

class _TransferNeedsTwoAccountsNotice extends StatelessWidget {
  const _TransferNeedsTwoAccountsNotice();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      icon: Icons.swap_horiz,
      message: 'A transfer needs at least two accounts.',
      color: AppTheme.neonCyan,
    );
  }
}

class _NoPeopleNotice extends StatelessWidget {
  const _NoPeopleNotice();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      icon: Icons.person_off_outlined,
      message: 'No people found. Add a person before editing loan entries.',
      color: AppTheme.neonRose,
    );
  }
}

DateTime _dateWithCurrentTime(DateTime date) {
  final now = DateTime.now();
  return DateTime(
    date.year,
    date.month,
    date.day,
    now.hour,
    now.minute,
    now.second,
  );
}

DateTime _dateWithOriginalTime(DateTime date, DateTime original) {
  final localOriginal = original.isUtc ? original.toLocal() : original;
  return DateTime(
    date.year,
    date.month,
    date.day,
    localOriginal.hour,
    localOriginal.minute,
    localOriginal.second,
  );
}

String _amountText(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}
