import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/amount_input.dart';
import '../../core/error_messages.dart';
import '../../core/formatters.dart';
import '../../data/loan_position.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

enum LoanAction { borrow, lend, repay, receive }

Future<bool?> showPersonEntrySheet(
  BuildContext context, {
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PersonEntrySheet(dataSource: dataSource),
    ),
  );
}

Future<bool?> showPersonEditSheet({
  required BuildContext context,
  required Person person,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          PersonEditSheet(person: person, dataSource: dataSource),
    ),
  );
}

Future<void> showPersonHistorySheet({
  required BuildContext context,
  required Person person,
  required List<TransactionRecord> transactions,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          PersonHistorySheet(person: person, transactions: transactions),
    ),
  );
}

Future<bool?> showLoanEntrySheet({
  required BuildContext context,
  required LoanAction action,
  required List<AccountBalance> accounts,
  required List<Person> people,
  String? initialPersonId,
  List<TransactionRecord>? transactions,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => LoanEntrySheet(
        action: action,
        accounts: accounts,
        people: people,
        initialPersonId: initialPersonId,
        transactions: transactions,
        dataSource: dataSource,
      ),
    ),
  );
}

class PersonEntrySheet extends StatefulWidget {
  const PersonEntrySheet({super.key, this.dataSource});

  final MoneyDataSource? dataSource;

  @override
  State<PersonEntrySheet> createState() => _PersonEntrySheetState();
}

class _PersonEntrySheetState extends State<PersonEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .createPerson(
            name: _nameController.text,
            phone: _phoneController.text,
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () => _error = 'Could not add person. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Add Person',
      accent: AppTheme.neonCyan,
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
                  children: [
                    const AppFormHeader(
                      title: 'Add Person',
                      subtitle: 'For lending, borrowing, and repayments',
                      icon: Icons.person_add_alt_1,
                      color: AppTheme.neonCyan,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
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
              accent: AppTheme.neonCyan,
              saveLabel: 'Add Person',
              isSaving: _isSaving,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class PersonEditSheet extends StatefulWidget {
  const PersonEditSheet({super.key, required this.person, this.dataSource});

  final Person person;
  final MoneyDataSource? dataSource;

  @override
  State<PersonEditSheet> createState() => _PersonEditSheetState();
}

class _PersonEditSheetState extends State<PersonEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.name);
    _phoneController = TextEditingController(text: widget.person.phone ?? '');
    _noteController = TextEditingController(text: widget.person.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .updatePerson(
            personId: widget.person.id,
            name: _nameController.text,
            phone: _phoneController.text,
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () =>
            _error = 'Could not update person. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Edit Person',
      accent: AppTheme.neonCyan,
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
                  children: [
                    const AppFormHeader(
                      title: 'Edit Person',
                      subtitle: 'Update their contact details',
                      icon: Icons.manage_accounts_outlined,
                      color: AppTheme.neonCyan,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
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
              accent: AppTheme.neonCyan,
              saveLabel: 'Save Changes',
              isSaving: _isSaving,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class LoanEntrySheet extends StatefulWidget {
  const LoanEntrySheet({
    super.key,
    required this.action,
    required this.accounts,
    required this.people,
    this.initialPersonId,
    this.transactions,
    this.dataSource,
  });

  final LoanAction action;
  final List<AccountBalance> accounts;
  final List<Person> people;
  final String? initialPersonId;

  /// All transactions, to show what's currently owed and warn when a
  /// repayment is more than that. Without them no balance is shown.
  final List<TransactionRecord>? transactions;
  final MoneyDataSource? dataSource;

  @override
  State<LoanEntrySheet> createState() => _LoanEntrySheetState();
}

class _LoanEntrySheetState extends State<LoanEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _accountId;
  String? _personId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.account.id;
    }
    _personId = widget.initialPersonId;
    if (!widget.people.any((person) => person.id == _personId) &&
        widget.people.isNotEmpty) {
      _personId = widget.people.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _type => switch (widget.action) {
    LoanAction.borrow => 'borrow',
    LoanAction.lend => 'lend',
    LoanAction.repay => 'repay',
    LoanAction.receive => 'receive',
  };

  String get _title => switch (widget.action) {
    LoanAction.borrow => 'Borrow Money',
    LoanAction.lend => 'Give Loan',
    LoanAction.repay => 'Repay Loan',
    LoanAction.receive => 'Receive Repayment',
  };

  String get _subtitle => switch (widget.action) {
    LoanAction.borrow => 'Money comes into your account',
    LoanAction.lend => 'Money goes out to someone',
    LoanAction.repay => 'You pay back money you borrowed',
    LoanAction.receive => 'Someone pays you back',
  };

  Color get _color => switch (widget.action) {
    LoanAction.borrow => AppTheme.neonAmber,
    LoanAction.lend => AppTheme.neonCyan,
    LoanAction.repay => AppTheme.neonRose,
    LoanAction.receive => AppTheme.neonEmerald,
  };

  IconData get _icon => switch (widget.action) {
    LoanAction.borrow => Icons.handshake_outlined,
    LoanAction.lend => Icons.volunteer_activism_outlined,
    LoanAction.repay => Icons.call_made,
    LoanAction.receive => Icons.call_received,
  };

  bool get _isRepayment =>
      widget.action == LoanAction.repay || widget.action == LoanAction.receive;

  String get _personName {
    for (final person in widget.people) {
      if (person.id == _personId) return person.name;
    }
    return 'this person';
  }

  /// The selected person's position, when transactions were provided.
  LoanPosition? get _position {
    final transactions = widget.transactions;
    final personId = _personId;
    if (transactions == null || personId == null) return null;
    return LoanPosition.from(
      transactions.where((transaction) => transaction.personId == personId),
    );
  }

  /// What's owed in the direction this repayment settles, as a helper line.
  String? get _owedHint {
    final position = _position;
    if (!_isRepayment || position == null) return null;
    final name = _personName;
    if (widget.action == LoanAction.repay) {
      return position.youOwe > 0
          ? 'You owe $name ${formatMoney(position.youOwe)}'
          : "You don't owe $name anything";
    }
    return position.theyOwe > 0
        ? '$name owes you ${formatMoney(position.theyOwe)}'
        : "$name doesn't owe you anything";
  }

  /// A warning when the amount is more than what's owed. The extra isn't
  /// lost (the ledger shows it as owed the other way), but it's usually a
  /// typo or the wrong action.
  String? get _overpaymentWarning {
    final position = _position;
    final amount = parseAmount(_amountController.text);
    if (!_isRepayment || position == null || amount == null || amount <= 0) {
      return null;
    }
    final name = _personName;
    final repaying = widget.action == LoanAction.repay;
    final owed = repaying ? position.youOwe : position.theyOwe;
    final extra = amount - owed;
    if (extra < 0.005) return null;
    final flipped = repaying ? '$name owing you' : 'you owing $name';
    return owed == 0
        ? 'Nothing is owed right now, so this will show as $flipped '
              '${formatMoney(amount)}.'
        : 'This is ${formatMoney(extra)} more than is owed. The extra will '
              'show as $flipped.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .createLoanTransaction(
            type: _type,
            amount: parseAmount(_amountController.text)!,
            accountId: _accountId!,
            personId: _personId!,
            occurredAt: _dateWithCurrentTime(_selectedDate),
            note: _noteController.text,
          );

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
    final next = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (next != null) {
      setState(() => _selectedDate = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: _title,
      accent: _color,
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
                  children: [
                    AppFormHeader(
                      title: _title,
                      subtitle: _subtitle,
                      icon: _icon,
                      color: _color,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _color.withValues(alpha: 0.13),
                        ),
                      ),
                      child: TextFormField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\u09F3 ',
                          prefixIcon: Icon(
                            Icons.payments_outlined,
                            color: _color,
                          ),
                        ),
                        onChanged: (_) {
                          if (_isRepayment) setState(() {});
                        },
                        validator: validateAmount,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _type == 'borrow' || _type == 'receive'
                            ? 'To account'
                            : 'From account',
                        prefixIcon: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: _color,
                        ),
                      ),
                      items: widget.accounts.map((item) {
                        return DropdownMenuItem(
                          value: item.account.id,
                          child: Text(
                            item.account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Select an account' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _personId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Person',
                        helperText: _owedHint,
                        prefixIcon: Icon(Icons.person_outline, color: _color),
                      ),
                      items: widget.people.map((person) {
                        return DropdownMenuItem(
                          value: person.id,
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _personId = value),
                      validator: (value) =>
                          value == null ? 'Select a person' : null,
                    ),
                    if (_overpaymentWarning case final warning?) ...[
                      const SizedBox(height: 12),
                      AppInlineNotice(
                        icon: Icons.info_outline,
                        message: warning,
                        color: AppTheme.neonAmber,
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: Icon(Icons.calendar_today, color: _color),
                        label: Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                        ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
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
              accent: _color,
              saveLabel: _title,
              isSaving: _isSaving,
              canSave: widget.accounts.isNotEmpty && widget.people.isNotEmpty,
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class PersonHistorySheet extends StatelessWidget {
  const PersonHistorySheet({
    super.key,
    required this.person,
    required this.transactions,
  });

  final Person person;
  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final rows = transactions.where((transaction) {
      return transaction.personId == person.id &&
          loanTransactionTypes.contains(transaction.type);
    }).toList()..sort((a, b) => b.displayDate.compareTo(a.displayDate));
    final summary = LoanPosition.from(rows);
    final receive = summary.netBalance >= 0;
    final color = receive ? AppTheme.neonEmerald : AppTheme.neonAmber;
    final status = receive ? 'They owe you' : 'You owe';

    return AppFormPage(
      title: person.name,
      accent: color,
      child: SingleChildScrollView(
        padding: appFormContentPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFormHeader(
              title: person.name,
              subtitle: person.phone?.isNotEmpty == true
                  ? person.phone!
                  : 'Loan history and balance',
              icon: Icons.receipt_long_outlined,
              color: color,
            ),
            if (person.note?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                person.note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _HistoryBalanceCard(
              status: status,
              amount: summary.netBalance.abs(),
              color: color,
              theyOwe: summary.theyOwe,
              youOwe: summary.youOwe,
            ),
            const SizedBox(height: 18),
            Text(
              'History',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const _HistoryEmptyState()
            else
              ...rows.map(
                (transaction) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PersonHistoryTile(transaction: transaction),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBalanceCard extends StatelessWidget {
  const _HistoryBalanceCard({
    required this.status,
    required this.amount,
    required this.color,
    required this.theyOwe,
    required this.youOwe,
  });

  final String status;
  final double amount;
  final Color color;
  final double theyOwe;
  final double youOwe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BalanceMiniStat(
                  label: 'They owe',
                  value: formatMoney(theyOwe),
                  color: AppTheme.neonEmerald,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BalanceMiniStat(
                  label: 'You owe',
                  value: formatMoney(youOwe),
                  color: AppTheme.neonAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMiniStat extends StatelessWidget {
  const _BalanceMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
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
    );
  }
}

class _PersonHistoryTile extends StatelessWidget {
  const _PersonHistoryTile({required this.transaction});

  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.type == 'lend' || transaction.type == 'repay';
    final color = positive ? AppTheme.neonEmerald : AppTheme.neonAmber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_loanIcon(transaction.type), color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loanLabel(transaction.type),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  [
                    formatShortDate(transaction.displayDate),
                    if (transaction.note?.isNotEmpty == true) transaction.note!,
                  ].join(' | '),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${positive ? '+' : '-'}${formatMoney(transaction.amount)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.history,
      title: 'No loan history yet',
      message: 'Borrowing and lending activity for this person will show here.',
      color: AppTheme.neonAmber,
      compact: true,
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

String _loanLabel(String type) {
  return switch (type) {
    'borrow' => 'Borrowed',
    'lend' => 'Lent',
    'repay' => 'Repaid',
    'receive' => 'Received',
    _ => type,
  };
}

IconData _loanIcon(String type) {
  return switch (type) {
    'borrow' => Icons.handshake_outlined,
    'lend' => Icons.volunteer_activism_outlined,
    'repay' => Icons.call_made,
    'receive' => Icons.call_received,
    _ => Icons.receipt_long_outlined,
  };
}
