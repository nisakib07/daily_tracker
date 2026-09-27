import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/amount_input.dart';
import '../../core/error_messages.dart';
import '../../core/formatters.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

Future<bool?> showInvestmentEntrySheet({
  required BuildContext context,
  required List<AccountBalance> accounts,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          InvestmentEntrySheet(accounts: accounts, dataSource: dataSource),
    ),
  );
}

Future<bool?> showInvestmentFundsSheet({
  required BuildContext context,
  required Investment investment,
  required List<AccountBalance> accounts,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => InvestmentFundsSheet(
        investment: investment,
        accounts: accounts,
        dataSource: dataSource,
      ),
    ),
  );
}

Future<bool?> showInvestmentReturnSheet({
  required BuildContext context,
  required List<Investment> investments,
  required List<AccountBalance> accounts,
  Investment? selectedInvestment,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => InvestmentReturnSheet(
        investments: investments,
        accounts: accounts,
        selectedInvestment: selectedInvestment,
        dataSource: dataSource,
      ),
    ),
  );
}

class InvestmentEntrySheet extends StatefulWidget {
  const InvestmentEntrySheet({
    super.key,
    required this.accounts,
    this.dataSource,
  });

  final List<AccountBalance> accounts;
  final MoneyDataSource? dataSource;

  @override
  State<InvestmentEntrySheet> createState() => _InvestmentEntrySheetState();
}

class _InvestmentEntrySheetState extends State<InvestmentEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.account.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
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
          .createInvestment(
            name: _nameController.text,
            description: _descriptionController.text,
            amount: parseAmount(_amountController.text)!,
            fromAccountId: _accountId!,
            occurredAt: _dateWithCurrentTime(_selectedDate),
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () => _error =
            'Could not create investment. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final next = await _pickInvestmentDate(context, _selectedDate);
    if (next != null) setState(() => _selectedDate = next);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'New Investment',
      accent: AppTheme.neonCyan,
      child: Form(
        key: _formKey,
        child: _InvestmentSheetBody(
          title: 'New Investment',
          subtitle: 'Track a business, asset, or fund',
          icon: Icons.trending_up,
          accent: AppTheme.neonCyan,
          actionLabel: 'Create Investment',
          isSaving: _isSaving,
          canSave: widget.accounts.isNotEmpty,
          error: _error,
          onCancel: () => Navigator.of(context).pop(false),
          onSave: _save,
          children: [
            _InvestmentAmountField(
              controller: _amountController,
              accent: AppTheme.neonCyan,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Investment name',
                prefixIcon: Icon(Icons.work_outline),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Enter a name';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.subject_outlined),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.accounts.isEmpty)
              const _NoInvestmentAccountsNotice()
            else
              _InvestmentAccountDropdown(
                label: 'From account',
                value: _accountId,
                accounts: widget.accounts,
                accent: AppTheme.neonCyan,
                onChanged: (value) => setState(() => _accountId = value),
              ),
            const SizedBox(height: 12),
            _InvestmentDateButton(
              date: _selectedDate,
              accent: AppTheme.neonCyan,
              onPressed: _pickDate,
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
          ],
        ),
      ),
    );
  }
}

class InvestmentFundsSheet extends StatefulWidget {
  const InvestmentFundsSheet({
    super.key,
    required this.investment,
    required this.accounts,
    this.dataSource,
  });

  final Investment investment;
  final List<AccountBalance> accounts;
  final MoneyDataSource? dataSource;

  @override
  State<InvestmentFundsSheet> createState() => _InvestmentFundsSheetState();
}

class _InvestmentFundsSheetState extends State<InvestmentFundsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.account.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
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
          .addInvestmentFunds(
            investmentId: widget.investment.id,
            amount: parseAmount(_amountController.text)!,
            fromAccountId: _accountId!,
            occurredAt: _dateWithCurrentTime(_selectedDate),
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () => _error = 'Could not add funds. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final next = await _pickInvestmentDate(context, _selectedDate);
    if (next != null) setState(() => _selectedDate = next);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Add Funds',
      accent: AppTheme.neonCyan,
      child: Form(
        key: _formKey,
        child: _InvestmentSheetBody(
          title: 'Add Funds',
          subtitle: widget.investment.name,
          icon: Icons.add,
          accent: AppTheme.neonCyan,
          actionLabel: 'Add Funds',
          isSaving: _isSaving,
          canSave: widget.accounts.isNotEmpty,
          error: _error,
          onCancel: () => Navigator.of(context).pop(false),
          onSave: _save,
          children: [
            _InvestmentAmountField(
              controller: _amountController,
              accent: AppTheme.neonCyan,
            ),
            const SizedBox(height: 16),
            _InvestmentInfoPill(
              label: 'Adding to',
              value: widget.investment.name,
            ),
            const SizedBox(height: 12),
            if (widget.accounts.isEmpty)
              const _NoInvestmentAccountsNotice()
            else
              _InvestmentAccountDropdown(
                label: 'From account',
                value: _accountId,
                accounts: widget.accounts,
                accent: AppTheme.neonCyan,
                onChanged: (value) => setState(() => _accountId = value),
              ),
            const SizedBox(height: 12),
            _InvestmentDateButton(
              date: _selectedDate,
              accent: AppTheme.neonCyan,
              onPressed: _pickDate,
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
          ],
        ),
      ),
    );
  }
}

class InvestmentReturnSheet extends StatefulWidget {
  const InvestmentReturnSheet({
    super.key,
    required this.investments,
    required this.accounts,
    this.selectedInvestment,
    this.dataSource,
  });

  final List<Investment> investments;
  final List<AccountBalance> accounts;
  final Investment? selectedInvestment;
  final MoneyDataSource? dataSource;

  @override
  State<InvestmentReturnSheet> createState() => _InvestmentReturnSheetState();
}

class _InvestmentReturnSheetState extends State<InvestmentReturnSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _investmentId;
  String? _accountId;
  DateTime _selectedDate = DateTime.now();
  bool _closeInvestment = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final selectedId = widget.selectedInvestment?.id;
    final selectedStillExists = widget.investments.any(
      (investment) => investment.id == selectedId,
    );
    _investmentId = selectedStillExists
        ? selectedId
        : (widget.investments.isEmpty ? null : widget.investments.first.id);
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.account.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
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
          .recordInvestmentReturn(
            investmentId: _investmentId!,
            amount: parseAmount(_amountController.text)!,
            toAccountId: _accountId!,
            occurredAt: _dateWithCurrentTime(_selectedDate),
            closeInvestment: _closeInvestment,
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(
        () =>
            _error = 'Could not record return. ${friendlyErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final next = await _pickInvestmentDate(context, _selectedDate);
    if (next != null) setState(() => _selectedDate = next);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = widget.accounts.isNotEmpty && widget.investments.isNotEmpty;

    return AppFormPage(
      title: 'Record Return',
      accent: AppTheme.neonEmerald,
      child: Form(
        key: _formKey,
        child: _InvestmentSheetBody(
          title: 'Record Return',
          subtitle: 'Money coming back from an investment',
          icon: Icons.call_received,
          accent: AppTheme.neonEmerald,
          actionLabel: 'Record Return',
          isSaving: _isSaving,
          canSave: canSave,
          error: _error,
          onCancel: () => Navigator.of(context).pop(false),
          onSave: _save,
          children: [
            _InvestmentAmountField(
              controller: _amountController,
              accent: AppTheme.neonEmerald,
            ),
            const SizedBox(height: 16),
            if (widget.investments.isEmpty)
              const _NoInvestmentsNotice()
            else
              DropdownButtonFormField<String>(
                initialValue: _investmentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Investment',
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: widget.investments.map((investment) {
                  return DropdownMenuItem(
                    value: investment.id,
                    child: Text(
                      investment.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _investmentId = value),
                validator: (value) =>
                    value == null ? 'Select an investment' : null,
              ),
            const SizedBox(height: 12),
            if (widget.accounts.isEmpty)
              const _NoInvestmentAccountsNotice()
            else
              _InvestmentAccountDropdown(
                label: 'To account',
                value: _accountId,
                accounts: widget.accounts,
                accent: AppTheme.neonEmerald,
                onChanged: (value) => setState(() => _accountId = value),
              ),
            const SizedBox(height: 12),
            _InvestmentDateButton(
              date: _selectedDate,
              accent: AppTheme.neonEmerald,
              onPressed: _pickDate,
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
            const SizedBox(height: 8),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: _closeInvestment,
                activeThumbColor: AppTheme.neonEmerald,
                secondary: const Icon(Icons.lock_outline),
                title: const Text('Close after return'),
                subtitle: const Text('Mark this investment as closed'),
                onChanged: (value) => setState(() => _closeInvestment = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentSheetBody extends StatelessWidget {
  const _InvestmentSheetBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.isSaving,
    required this.canSave,
    required this.error,
    required this.children,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final bool isSaving;
  final bool canSave;
  final String? error;
  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: ValueKey('investment-form-scroll-$actionLabel'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: appFormContentPadding(context),
            children: [
              AppFormHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: accent,
              ),
              const SizedBox(height: 18),
              ...children,
              if (error != null) ...[
                const SizedBox(height: 12),
                _InvestmentError(message: error!),
              ],
            ],
          ),
        ),
        AppFormActionBar(
          accent: accent,
          saveLabel: actionLabel,
          isSaving: isSaving,
          canSave: canSave,
          onCancel: onCancel,
          onSave: onSave,
        ),
      ],
    );
  }
}

class _InvestmentAmountField extends StatelessWidget {
  const _InvestmentAmountField({
    required this.controller,
    required this.accent,
  });

  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: TextFormField(
        key: const ValueKey('investment-amount'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          labelText: 'Amount',
          prefixText: '\u09F3 ',
          prefixIcon: Icon(Icons.payments_outlined, color: accent),
        ),
        validator: validateAmount,
      ),
    );
  }
}

class _InvestmentAccountDropdown extends StatelessWidget {
  const _InvestmentAccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<AccountBalance> accounts;
  final Color accent;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: accent),
      ),
      items: accounts.map((item) {
        return DropdownMenuItem(
          value: item.account.id,
          child: Text(
            '${item.account.name}  ${formatMoney(item.balance)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select an account' : null,
    );
  }
}

class _InvestmentDateButton extends StatelessWidget {
  const _InvestmentDateButton({
    required this.date,
    required this.accent,
    required this.onPressed,
  });

  final DateTime date;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.calendar_today, color: accent),
        label: Text(
          DateFormat('MMM d, yyyy').format(date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _InvestmentInfoPill extends StatelessWidget {
  const _InvestmentInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppTheme.neonCyan, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoInvestmentAccountsNotice extends StatelessWidget {
  const _NoInvestmentAccountsNotice();

  @override
  Widget build(BuildContext context) {
    return const _InvestmentNotice(
      icon: Icons.account_balance_wallet_outlined,
      message: 'No accounts found. Add or restore accounts before investing.',
    );
  }
}

class _NoInvestmentsNotice extends StatelessWidget {
  const _NoInvestmentsNotice();

  @override
  Widget build(BuildContext context) {
    return const _InvestmentNotice(
      icon: Icons.trending_up,
      message: 'No active investments found.',
    );
  }
}

class _InvestmentNotice extends StatelessWidget {
  const _InvestmentNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppInlineNotice(
      icon: icon,
      message: message,
      color: AppTheme.neonRose,
    );
  }
}

class _InvestmentError extends StatelessWidget {
  const _InvestmentError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
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

Future<DateTime?> _pickInvestmentDate(
  BuildContext context,
  DateTime initialDate,
) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.neonCyan),
        ),
        child: child!,
      );
    },
  );
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
