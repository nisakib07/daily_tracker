import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../data/money_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';

Future<bool?> showAccountEditSheet({
  required BuildContext context,
  required AccountBalance accountBalance,
  MoneyDataSource? dataSource,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => AccountEditSheet(
        accountBalance: accountBalance,
        dataSource: dataSource,
      ),
    ),
  );
}

class AccountEditSheet extends StatefulWidget {
  const AccountEditSheet({
    super.key,
    required this.accountBalance,
    this.dataSource,
  });

  final AccountBalance accountBalance;
  final MoneyDataSource? dataSource;

  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _addMoney = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.accountBalance.account.name;
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await (widget.dataSource ?? MoneyRepository(Supabase.instance.client))
          .updateAccount(
            accountId: widget.accountBalance.account.id,
            name: _nameController.text,
            adjustmentAmount: _adjustmentAmount,
            addMoney: _addMoney,
            note: _noteController.text,
          );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not save account. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double get _adjustmentAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0;
  }

  double get _previewBalance {
    final direction = _addMoney ? 1 : -1;
    return widget.accountBalance.balance + (_adjustmentAmount * direction);
  }

  Color get _accountColor {
    return switch (widget.accountBalance.account.type) {
      'cash' => AppTheme.neonEmerald,
      'wallet' => AppTheme.neonCyan,
      'card' => AppTheme.neonAmber,
      _ => AppTheme.neonViolet,
    };
  }

  IconData get _accountIcon {
    return switch (widget.accountBalance.account.type) {
      'cash' => Icons.payments_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      'card' => Icons.credit_card,
      _ => Icons.account_balance_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Edit Account',
      accent: _accountColor,
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
                      title: 'Edit Account',
                      subtitle:
                          'Current balance ${formatMoney(widget.accountBalance.balance)}',
                      icon: _accountIcon,
                      color: _accountColor,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter an account name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.balance, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Balance Adjustment',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            expandedInsets: EdgeInsets.zero,
                            selected: {_addMoney},
                            onSelectionChanged: (selection) {
                              setState(() => _addMoney = selection.first);
                            },
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(Icons.south_west),
                                label: Text('Add'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(Icons.north_east),
                                label: Text('Remove'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _amountController,
                            builder: (context, value, _) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount',
                                      hintText: 'Optional',
                                      prefixText: '\u09F3 ',
                                      prefixIcon: Icon(Icons.payments_outlined),
                                    ),
                                    validator: (value) {
                                      final text = (value ?? '').trim();
                                      if (text.isEmpty) return null;
                                      final amount = double.tryParse(text);
                                      if (amount == null || amount < 0) {
                                        return 'Enter 0 or more';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (_adjustmentAmount > 0) ...[
                                    const SizedBox(height: 10),
                                    _PreviewBalance(
                                      balance: _previewBalance,
                                      addMoney: _addMoney,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_adjustmentAmount > 0) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Adjustment note',
                          hintText: 'Optional',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AppFormActionBar(
              accent: _accountColor,
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

class _PreviewBalance extends StatelessWidget {
  const _PreviewBalance({required this.balance, required this.addMoney});

  final double balance;
  final bool addMoney;

  @override
  Widget build(BuildContext context) {
    final color = addMoney ? AppTheme.neonEmerald : AppTheme.neonRose;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(addMoney ? Icons.south_west : Icons.north_east, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'New balance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              formatMoney(balance),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
