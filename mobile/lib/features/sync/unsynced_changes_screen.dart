import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../data/cached_money_data_source.dart';
import '../../data/money_repository.dart';
import '../../data/offline_mutation_queue.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

Future<void> showUnsyncedChangesScreen({
  required BuildContext context,
  required CachedMoneyDataSource dataSource,
  DashboardSnapshot? snapshot,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          UnsyncedChangesScreen(dataSource: dataSource, snapshot: snapshot),
    ),
  );
}

/// Lists changes saved on this device that the server refused, so none of
/// them are lost silently. Each can be sent again or thrown away.
class UnsyncedChangesScreen extends StatefulWidget {
  const UnsyncedChangesScreen({
    super.key,
    required this.dataSource,
    this.snapshot,
  });

  final CachedMoneyDataSource dataSource;

  /// Used to show account, person and investment names instead of ids.
  final DashboardSnapshot? snapshot;

  @override
  State<UnsyncedChangesScreen> createState() => _UnsyncedChangesScreenState();
}

class _UnsyncedChangesScreenState extends State<UnsyncedChangesScreen> {
  StreamSubscription<int>? _statusSubscription;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget.dataSource.statusChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retry({String? id}) async {
    setState(() => _isBusy = true);
    try {
      await widget.dataSource.retryFailedMutations(id: id);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _discard(QueuedMoneyMutation mutation) async {
    final description = describeQueuedMutation(mutation, widget.snapshot);
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Discard this change?',
      message:
          '"${description.title}" will not be saved. This cannot be undone.',
      confirmLabel: 'Discard',
    );
    if (!confirmed || !mounted) return;
    await widget.dataSource.discardFailedMutation(mutation.id);
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.dataSource.failedMutations;
    return AppFormPage(
      title: 'Unsaved changes',
      accent: AppTheme.neonRose,
      child: SingleChildScrollView(
        padding: appFormContentPadding(context),
        child: failed.isEmpty
            ? AppEmptyState(
                icon: Icons.cloud_done_outlined,
                title: 'Nothing left to fix',
                message: 'Every change on this device has been dealt with.',
                color: AppTheme.neonEmerald,
                actionLabel: 'Back to dashboard',
                onAction: () => Navigator.of(context).pop(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppFormHeader(
                    title: "These changes weren't saved",
                    subtitle:
                        'The server refused them. Try again, or discard '
                        "the ones you don't need.",
                    icon: Icons.cloud_off_outlined,
                    color: AppTheme.neonRose,
                  ),
                  if (failed.length > 1) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : () => _retry(),
                      icon: const Icon(Icons.refresh),
                      label: Text('Try all ${failed.length} again'),
                    ),
                  ],
                  for (final mutation in failed) ...[
                    const SizedBox(height: 12),
                    _FailedChangeCard(
                      mutation: mutation,
                      description: describeQueuedMutation(
                        mutation,
                        widget.snapshot,
                      ),
                      isBusy: _isBusy,
                      onRetry: () => _retry(id: mutation.id),
                      onDiscard: () => _discard(mutation),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _FailedChangeCard extends StatelessWidget {
  const _FailedChangeCard({
    required this.mutation,
    required this.description,
    required this.isBusy,
    required this.onRetry,
    required this.onDiscard,
  });

  final QueuedMoneyMutation mutation;
  final MutationDescription description;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              description.title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description.detail,
                style: textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              mutation.failureReason ?? 'The server refused it.',
              style: textTheme.bodySmall?.copyWith(color: AppTheme.neonRose),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: isBusy ? null : onDiscard,
                  child: const Text('Discard'),
                ),
                TextButton(
                  onPressed: isBusy ? null : onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MutationDescription {
  const MutationDescription(this.title, this.detail);

  final String title;
  final String detail;
}

/// Describes a queued change in words, using [snapshot] (when available) to
/// name the accounts, people and investments it refers to.
MutationDescription describeQueuedMutation(
  QueuedMoneyMutation mutation,
  DashboardSnapshot? snapshot,
) {
  final payload = mutation.payload;
  String money(String key) => formatMoney(_number(payload[key]));
  String text(String key) => payload[key]?.toString().trim() ?? '';
  String account(String key) {
    final id = payload[key]?.toString();
    final match = snapshot?.accounts.where((item) => item.id == id);
    return match == null || match.isEmpty ? 'an account' : match.first.name;
  }

  String person(String key) {
    final id = payload[key]?.toString();
    final match = snapshot?.people.where((item) => item.id == id);
    return match == null || match.isEmpty ? 'a person' : match.first.name;
  }

  String investment(String key) {
    final id = payload[key]?.toString();
    final match = snapshot?.investments.where((item) => item.id == id);
    return match == null || match.isEmpty ? 'an investment' : match.first.name;
  }

  final date = _date(payload['occurred_at']);
  String join(List<String> parts) {
    return [...parts, ?date].where((part) => part.isNotEmpty).join(' · ');
  }

  String month(String key) {
    final parsed = DateTime.tryParse(text(key));
    return parsed == null ? '' : formatMonth(parsed);
  }

  return switch (mutation.kind) {
    'money_in' => MutationDescription(
      'Income ${money('amount')}',
      join([text('category'), 'to ${account('account_id')}']),
    ),
    'money_out' => MutationDescription(
      'Expense ${money('amount')}',
      join([text('category'), 'from ${account('account_id')}']),
    ),
    'transfer' => MutationDescription(
      'Transfer ${money('amount')}',
      join([
        'from ${account('from_account_id')} to ${account('to_account_id')}',
      ]),
    ),
    'loan' => MutationDescription(
      '${_loanLabel(text('type'))} ${money('amount')}',
      join([person('person_id'), account('account_id')]),
    ),
    'create_person' => MutationDescription('Add person', text('name')),
    'update_person' => MutationDescription('Edit person', text('name')),
    'delete_person' => MutationDescription(
      'Delete person',
      person('person_id'),
    ),
    'update_account' => MutationDescription(
      'Update account',
      _number(payload['adjustment_amount']) > 0
          ? '${text('name')} · ${payload['add_money'] == true ? 'add' : 'remove'} '
                '${money('adjustment_amount')}'
          : text('name'),
    ),
    'create_investment' => MutationDescription(
      'New investment ${money('amount')}',
      join([text('name'), 'from ${account('from_account_id')}']),
    ),
    'add_investment_funds' => MutationDescription(
      'Add to investment ${money('amount')}',
      join([investment('investment_id'), 'from ${account('from_account_id')}']),
    ),
    'investment_return' => MutationDescription(
      'Investment return ${money('amount')}',
      join([
        investment('investment_id'),
        'to ${account('to_account_id')}',
        if (payload['close_investment'] == true) 'closes it',
      ]),
    ),
    'update_transaction' => MutationDescription(
      'Edit transaction ${money('amount')}',
      join([text('category')]),
    ),
    'delete_transaction' => MutationDescription(
      'Delete transaction',
      _describeTransaction(snapshot, text('transaction_id')),
    ),
    'delete_investment' => MutationDescription(
      'Delete investment',
      investment('investment_id'),
    ),
    'replace_budgets' => MutationDescription('Update budgets', month('month')),
    'clear_budgets' => MutationDescription('Clear budgets', month('month')),
    _ => MutationDescription('Change', mutation.kind),
  };
}

String _describeTransaction(DashboardSnapshot? snapshot, String id) {
  final match = snapshot?.transactions.where((item) => item.id == id);
  if (match == null || match.isEmpty) return '';
  final transaction = match.first;
  return [
    transaction.category ?? transaction.type,
    formatMoney(transaction.amount),
    DateFormat('d MMM yyyy').format(transaction.displayDate),
  ].join(' · ');
}

String _loanLabel(String type) {
  return switch (type) {
    'borrow' => 'Borrowed',
    'lend' => 'Loan given',
    'repay' => 'Loan repaid',
    'receive' => 'Repayment received',
    _ => 'Loan',
  };
}

String? _date(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return DateFormat('d MMM yyyy').format(parsed.toLocal());
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
