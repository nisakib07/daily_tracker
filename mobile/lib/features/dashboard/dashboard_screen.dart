import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../data/ai_service.dart';
import '../../data/cached_money_data_source.dart';
import '../../data/money_repository.dart';
import '../../models/money_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_state_widgets.dart';
import '../../shared/widgets/aurora_background.dart';
import '../accounts/account_edit_sheet.dart';
import '../analytics/analytics_sheet.dart';
import '../budget/budget_entry_sheet.dart';
import '../investments/investment_entry_sheets.dart';
import '../people/people_entry_sheets.dart';
import '../settings/settings_sheet.dart';
import '../transactions/transaction_entry_sheet.dart';

enum DashboardTab { activity, ledger, budget, investments }

enum ActivityMode { daily, monthly }

enum _QuickAction { income, expense, transfer, investment }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    this.snapshotLoader,
    this.dataSource,
    this.aiService,
  });

  final User user;
  final Future<DashboardSnapshot> Function()? snapshotLoader;
  final MoneyDataSource? dataSource;
  final AiService? aiService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late Future<DashboardSnapshot> _snapshotFuture;
  StreamSubscription<DashboardSnapshot>? _cacheSubscription;
  StreamSubscription<int>? _cacheStatusSubscription;
  final TextEditingController _activitySearchController =
      TextEditingController();
  final GlobalKey _tabContentKey = GlobalKey();
  bool _isMutating = false;
  DashboardTab _activeTab = DashboardTab.activity;
  ActivityMode _activityMode = ActivityMode.daily;
  String _typeFilter = 'all';
  String _activityAccountFilter = 'all';
  String _activitySearchQuery = '';
  int _activityVisibleLimit = 100;
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedActivityMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  MoneyDataSource get _dataSource =>
      widget.dataSource ?? MoneyRepository(Supabase.instance.client);
  late final AiService _aiService = widget.aiService ?? AiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapshotFuture = _load();
    final dataSource = widget.dataSource;
    if (dataSource is CachedMoneyDataSource) {
      _cacheSubscription = dataSource.snapshots.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _snapshotFuture = Future<DashboardSnapshot>.value(snapshot);
        });
      });
      _cacheStatusSubscription = dataSource.statusChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cacheSubscription?.cancel();
    _cacheStatusSubscription?.cancel();
    _activitySearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final dataSource = widget.dataSource;
    if (dataSource is CachedMoneyDataSource && dataSource.hasStaleData) {
      unawaited(_refresh());
    }
  }

  Future<DashboardSnapshot> _load() {
    return widget.snapshotLoader?.call() ?? _dataSource.fetchDashboard();
  }

  Future<void> _refresh({bool forceRemote = false}) async {
    if (!mounted) return;
    final cachedDataSource = widget.dataSource;
    final hasCachedSnapshot =
        cachedDataSource is CachedMoneyDataSource &&
        cachedDataSource.snapshot != null;
    final nextSnapshot =
        forceRemote && cachedDataSource is CachedMoneyDataSource
        ? cachedDataSource.refresh()
        : _load();

    if (!hasCachedSnapshot) {
      setState(() {
        _snapshotFuture = nextSnapshot;
      });
    }

    try {
      await nextSnapshot;
    } catch (_) {
      // FutureBuilder presents the retry state.
    }
  }

  Future<void> _refreshAfterMutation(String message) async {
    if (mounted) setState(() => _isMutating = true);
    try {
      await _refresh();
      if (!mounted) return;
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _showEntrySheet(
    TransactionEntryKind kind,
    DashboardSnapshot snapshot,
  ) async {
    final saved = await showTransactionEntrySheet(
      context: context,
      kind: kind,
      accounts: snapshot.accountBalances,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refreshAfterMutation('Transaction saved');
  }

  Future<void> _showAccountSheet(AccountBalance accountBalance) async {
    final saved = await showAccountEditSheet(
      context: context,
      accountBalance: accountBalance,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Account updated');
  }

  Future<void> _showAnalytics() async {
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      await showAnalyticsSheet(
        context: context,
        snapshot: snapshot,
        aiService: _aiService,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Analytics will open after dashboard data loads.');
    }
  }

  Future<void> _showPersonSheet() async {
    final saved = await showPersonEntrySheet(
      context,
      dataSource: widget.dataSource,
    );
    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Person added');
  }

  Future<void> _showPersonEditSheet(Person person) async {
    final saved = await showPersonEditSheet(
      context: context,
      person: person,
      dataSource: widget.dataSource,
    );
    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Person updated');
  }

  Future<void> _showPersonHistorySheet(
    Person person,
    DashboardSnapshot snapshot,
  ) async {
    await showPersonHistorySheet(
      context: context,
      person: person,
      transactions: snapshot.transactions,
    );
  }

  Future<void> _deletePerson(Person person) async {
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Delete Person?',
      message:
          'Remove ${person.name} from the ledger? Their existing transactions will remain in Activity.',
      confirmLabel: 'Delete Person',
      icon: Icons.person_remove_outlined,
    );

    if (!mounted || !confirmed) return;

    setState(() => _isMutating = true);
    try {
      await _dataSource.deletePerson(person.id);
      await _refresh();

      if (!mounted) return;
      _showSnack('Person deleted');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete person. Please try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _showLoanSheet(
    LoanAction action,
    DashboardSnapshot snapshot, {
    String? personId,
  }) async {
    final saved = await showLoanEntrySheet(
      context: context,
      action: action,
      accounts: snapshot.accountBalances,
      people: snapshot.people,
      initialPersonId: personId,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Loan entry saved');
  }

  Future<void> _showEditTransactionSheet(
    DashboardSnapshot snapshot,
    TransactionRecord transaction,
  ) async {
    final saved = await showEditTransactionSheet(
      context: context,
      transaction: transaction,
      accounts: snapshot.accountBalances,
      people: snapshot.people,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refreshAfterMutation('Transaction updated');
  }

  Future<void> _showBudgetSheet(DashboardSnapshot snapshot) async {
    final budgetRows = _budgetRowsForMonth(snapshot, _selectedMonth);
    final existingBudgets = {
      for (final budget in snapshot.budgets.where((budget) {
        return _isSameMonth(budget.month, _selectedMonth);
      }))
        budget.category: budget.amount,
    };

    final saved = await showBudgetEntrySheet(
      context: context,
      month: _selectedMonth,
      categories: budgetRows.map((row) => row.category).toList(),
      existingBudgets: existingBudgets,
      transactions: snapshot.transactions,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Budgets updated');
  }

  Future<void> _showInvestmentSheet(DashboardSnapshot snapshot) async {
    final saved = await showInvestmentEntrySheet(
      context: context,
      accounts: snapshot.accountBalances,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Investment created');
  }

  Future<void> _showInvestmentFundsSheet(
    DashboardSnapshot snapshot,
    Investment investment,
  ) async {
    final saved = await showInvestmentFundsSheet(
      context: context,
      investment: investment,
      accounts: snapshot.accountBalances,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Investment funds added');
  }

  Future<void> _showInvestmentReturnSheet(
    DashboardSnapshot snapshot, {
    Investment? investment,
  }) async {
    final activeInvestments = snapshot.investments
        .where((item) => item.status == 'active')
        .toList();
    final saved = await showInvestmentReturnSheet(
      context: context,
      investments: activeInvestments,
      accounts: snapshot.accountBalances,
      selectedInvestment: investment,
      dataSource: widget.dataSource,
    );

    if (!mounted || saved != true) return;
    await _refresh();

    if (!mounted) return;
    _showSnack('Investment return recorded');
  }

  Future<void> _deleteInvestment(Investment investment) async {
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Delete Investment?',
      message:
          'Delete this investment and all linked transactions? Account balances will be recalculated.',
      confirmLabel: 'Delete Investment',
      icon: Icons.trending_down,
    );

    if (!mounted || !confirmed) return;

    setState(() => _isMutating = true);
    try {
      await _dataSource.deleteInvestment(investment.id);
      await _refresh();

      if (!mounted) return;
      _showSnack('Investment deleted');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete investment. Please try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _pickActivityDay() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(today) ? today : _selectedDay,
      firstDate: DateTime(2020),
      lastDate: today,
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedDay = picked;
      _activityVisibleLimit = 100;
    });
  }

  Future<void> _pickActivityMonth() async {
    final nowMonth = _monthOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      helpText: 'Pick a month',
      initialDate: _selectedActivityMonth.isAfter(nowMonth)
          ? nowMonth
          : _selectedActivityMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(nowMonth.year, nowMonth.month + 1, 0),
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedActivityMonth = DateTime(picked.year, picked.month);
      _selectedMonth = DateTime(picked.year, picked.month);
      _activityVisibleLimit = 100;
    });
  }

  void _changeActivityDay(int days) {
    final today = _dateOnly(DateTime.now());
    final next = _dateOnly(_selectedDay.add(Duration(days: days)));
    if (next.isAfter(today)) return;
    setState(() {
      _selectedDay = next;
      _activityVisibleLimit = 100;
    });
  }

  void _changeActivityMonth(int months) {
    final nowMonth = _monthOnly(DateTime.now());
    final next = DateTime(
      _selectedActivityMonth.year,
      _selectedActivityMonth.month + months,
    );
    if (next.isAfter(nowMonth)) return;
    setState(() {
      _selectedActivityMonth = next;
      _selectedMonth = next;
      _activityVisibleLimit = 100;
    });
  }

  Future<void> _deleteTransaction(TransactionRecord transaction) async {
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Delete Transaction?',
      message:
          'Remove this transaction? The affected account balance will update immediately.',
      confirmLabel: 'Delete Transaction',
    );

    if (!mounted || !confirmed) return;

    setState(() => _isMutating = true);
    try {
      await _dataSource.deleteTransaction(transaction.id);
      await _refreshAfterMutation('Transaction deleted');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete transaction. Refresh and try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _changeTab(DashboardTab tab, {bool reveal = false}) {
    setState(() => _activeTab = tab);
    if (!reveal) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = _tabContentKey.currentContext;
      if (!mounted || tabContext == null) return;
      Scrollable.ensureVisible(
        tabContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cachedDataSource = widget.dataSource;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < 360;
    final wide = viewportWidth >= 760;
    final contentPadding = compact
        ? 12.0
        : wide
        ? 24.0
        : 16.0;
    final fabRightInset = viewportWidth > 1120
        ? (viewportWidth - 1120) / 2
        : 0.0;

    return Scaffold(
      appBar: _DashboardTopBar(
        email: widget.user.email,
        compact: compact,
        onRefresh: () {
          _refresh(forceRemote: true);
        },
        onAnalytics: _showAnalytics,
        onSettings: () {
          showSettingsSheet(context: context, email: widget.user.email);
        },
        onSignOut: _signOut,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: _isMutating,
              child: FutureBuilder<DashboardSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  // Once we have data once, keep showing it through later
                  // background refreshes instead of flashing back to a
                  // loading placeholder while the new future settles.
                  if (!snapshot.hasData) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _LoadingState();
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(onRetry: _refresh);
                    }
                  }

                  final data = snapshot.requireData;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = constraints.maxWidth > 1120
                          ? 1120.0
                          : constraints.maxWidth;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          key: const ValueKey('dashboard-content'),
                          width: contentWidth,
                          height: constraints.maxHeight,
                          child: RefreshIndicator(
                            onRefresh: () => _refresh(forceRemote: true),
                            child: ListView(
                              key: const ValueKey('dashboard-scroll-view'),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                contentPadding,
                                wide ? 24 : 16,
                                contentPadding,
                                wide ? 48 : 32,
                              ),
                              children: [
                                if (cachedDataSource is CachedMoneyDataSource &&
                                    cachedDataSource.pendingMutationCount >
                                        0) ...[
                                  AppInlineNotice(
                                    icon: Icons.cloud_upload_outlined,
                                    message:
                                        '${cachedDataSource.pendingMutationCount} change${cachedDataSource.pendingMutationCount == 1 ? '' : 's'} waiting to sync.',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (cachedDataSource is CachedMoneyDataSource &&
                                    cachedDataSource.lastSyncError != null) ...[
                                  const AppInlineNotice(
                                    icon: Icons.cloud_off_outlined,
                                    message:
                                        'Showing saved data. We will sync again when the connection returns.',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _DashboardOverview(
                                  snapshot: data,
                                  email: widget.user.email,
                                  onEditAccount: _showAccountSheet,
                                ),
                                SizedBox(height: wide ? 20 : 16),
                                _MonthlyStatsPanel(
                                  snapshot: data,
                                  selectedMonth: _selectedMonth,
                                  onPrevious: () {
                                    setState(() {
                                      _selectedMonth = DateTime(
                                        _selectedMonth.year,
                                        _selectedMonth.month - 1,
                                      );
                                    });
                                  },
                                  onNext: () {
                                    final nowMonth = DateTime(
                                      DateTime.now().year,
                                      DateTime.now().month,
                                    );
                                    final next = DateTime(
                                      _selectedMonth.year,
                                      _selectedMonth.month + 1,
                                    );
                                    if (next.isAfter(nowMonth)) return;
                                    setState(() => _selectedMonth = next);
                                  },
                                ),
                                SizedBox(height: wide ? 20 : 16),
                                if (wide) ...[
                                  _DashboardTabBar(
                                    activeTab: _activeTab,
                                    onChanged: _changeTab,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                KeyedSubtree(
                                  key: _tabContentKey,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: KeyedSubtree(
                                      key: ValueKey(_activeTab),
                                      child: _DashboardTabContent(
                                        activeTab: _activeTab,
                                        snapshot: data,
                                        activityMode: _activityMode,
                                        selectedDay: _selectedDay,
                                        selectedActivityMonth:
                                            _selectedActivityMonth,
                                        typeFilter: _typeFilter,
                                        activityAccountFilter:
                                            _activityAccountFilter,
                                        activitySearchController:
                                            _activitySearchController,
                                        activitySearchQuery:
                                            _activitySearchQuery,
                                        activityVisibleLimit:
                                            _activityVisibleLimit,
                                        onLoadMoreActivity: () => setState(
                                          () => _activityVisibleLimit += 100,
                                        ),
                                        onActivityModeChanged: (value) =>
                                            setState(() {
                                              _activityMode = value;
                                              _activityVisibleLimit = 100;
                                            }),
                                        onPreviousActivityDay: () =>
                                            _changeActivityDay(-1),
                                        onNextActivityDay: () =>
                                            _changeActivityDay(1),
                                        onPickActivityDay: _pickActivityDay,
                                        onTodayActivity: () => setState(() {
                                          _selectedDay = DateTime.now();
                                          _activityVisibleLimit = 100;
                                        }),
                                        onPreviousActivityMonth: () =>
                                            _changeActivityMonth(-1),
                                        onNextActivityMonth: () =>
                                            _changeActivityMonth(1),
                                        onPickActivityMonth: _pickActivityMonth,
                                        onTypeFilterChanged: (value) =>
                                            setState(() {
                                              _typeFilter = value;
                                              _activityVisibleLimit = 100;
                                            }),
                                        onActivityAccountFilterChanged:
                                            (value) {
                                              setState(() {
                                                _activityAccountFilter = value;
                                                _activityVisibleLimit = 100;
                                              });
                                            },
                                        onActivitySearchChanged: (value) {
                                          setState(() {
                                            _activitySearchQuery = value;
                                            _activityVisibleLimit = 100;
                                          });
                                        },
                                        onClearActivitySearch: () {
                                          _activitySearchController.clear();
                                          setState(() {
                                            _activitySearchQuery = '';
                                            _activityVisibleLimit = 100;
                                          });
                                        },
                                        onEditTransaction: (transaction) {
                                          _showEditTransactionSheet(
                                            data,
                                            transaction,
                                          );
                                        },
                                        onDeleteTransaction: _deleteTransaction,
                                        onAddPerson: _showPersonSheet,
                                        onLoanAction: (action, personId) {
                                          _showLoanSheet(
                                            action,
                                            data,
                                            personId: personId,
                                          );
                                        },
                                        onViewPerson: (person) {
                                          _showPersonHistorySheet(person, data);
                                        },
                                        onEditPerson: _showPersonEditSheet,
                                        onDeletePerson: _deletePerson,
                                        selectedBudgetMonth: _selectedMonth,
                                        onPreviousBudgetMonth: () {
                                          setState(() {
                                            _selectedMonth = DateTime(
                                              _selectedMonth.year,
                                              _selectedMonth.month - 1,
                                            );
                                          });
                                        },
                                        onNextBudgetMonth: () {
                                          final nowMonth = DateTime(
                                            DateTime.now().year,
                                            DateTime.now().month,
                                          );
                                          final next = DateTime(
                                            _selectedMonth.year,
                                            _selectedMonth.month + 1,
                                          );
                                          if (next.isAfter(nowMonth)) return;
                                          setState(() => _selectedMonth = next);
                                        },
                                        onOpenBudget: () =>
                                            _showBudgetSheet(data),
                                        onNewInvestment: () =>
                                            _showInvestmentSheet(data),
                                        onAddInvestmentFunds: (investment) {
                                          _showInvestmentFundsSheet(
                                            data,
                                            investment,
                                          );
                                        },
                                        onRecordInvestmentReturn: (investment) {
                                          _showInvestmentReturnSheet(
                                            data,
                                            investment: investment,
                                          );
                                        },
                                        onDeleteInvestment: _deleteInvestment,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (_isMutating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Semantics(
                label: 'Updating dashboard',
                child: const LinearProgressIndicator(
                  key: ValueKey('dashboard-mutation-progress'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FutureBuilder<DashboardSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final data = snapshot.requireData;
          return Padding(
            padding: EdgeInsets.only(right: fabRightInset),
            child: FloatingActionButton(
              tooltip: 'Quick actions',
              onPressed: () => _showQuickActions(context, data),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
      bottomNavigationBar: wide
          ? null
          : _MobileDashboardNav(
              activeTab: _activeTab,
              onChanged: (tab) => _changeTab(tab, reveal: true),
            ),
    );
  }

  Future<void> _showQuickActions(
    BuildContext sheetContext,
    DashboardSnapshot snapshot,
  ) async {
    final action = await showModalBottomSheet<_QuickAction>(
      context: sheetContext,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _QuickActionsSheet(
          onIncome: () => Navigator.of(context).pop(_QuickAction.income),
          onExpense: () => Navigator.of(context).pop(_QuickAction.expense),
          onTransfer: () => Navigator.of(context).pop(_QuickAction.transfer),
          onInvestment: () =>
              Navigator.of(context).pop(_QuickAction.investment),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _QuickAction.income:
        await _showEntrySheet(TransactionEntryKind.income, snapshot);
      case _QuickAction.expense:
        await _showEntrySheet(TransactionEntryKind.expense, snapshot);
      case _QuickAction.transfer:
        await _showEntrySheet(TransactionEntryKind.transfer, snapshot);
      case _QuickAction.investment:
        await _showInvestmentSheet(snapshot);
    }
  }
}

/// Animates a money figure counting from its previous value to [value]
/// whenever it changes, without replaying on unrelated rebuilds.
class _AnimatedMoney extends StatefulWidget {
  const _AnimatedMoney({required this.value, this.style});

  final double value;
  final TextStyle? style;

  @override
  State<_AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<_AnimatedMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );
  late Animation<double> _animation;
  late double _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _animation = _buildAnimation(0, widget.value);
    _controller.forward(from: 0);
  }

  Animation<double> _buildAnimation(double begin, double end) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _previousValue) {
      _animation = _buildAnimation(_previousValue, widget.value);
      _previousValue = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          formatMoney(_animation.value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}

class _DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardTopBar({
    required this.email,
    required this.compact,
    required this.onRefresh,
    required this.onAnalytics,
    required this.onSettings,
    required this.onSignOut,
  });

  final String? email;
  final bool compact;
  final VoidCallback onRefresh;
  final VoidCallback onAnalytics;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Center(
        child: ConstrainedBox(
          key: const ValueKey('dashboard-topbar-content'),
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
            child: Row(
              children: [
                Container(
                  width: compact ? 36 : 40,
                  height: compact ? 36 : 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.neonEmerald, AppTheme.neonCyan],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonEmerald.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF04231A),
                    size: 22,
                  ),
                ),
                SizedBox(width: compact ? 9 : 12),
                Expanded(
                  child: Text(
                    'Money Master',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!compact)
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                IconButton(
                  tooltip: 'Analytics',
                  onPressed: onAnalytics,
                  icon: const Icon(Icons.bar_chart_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  icon: const Icon(Icons.person_outline_rounded),
                  onSelected: (value) {
                    if (value == 'refresh') onRefresh();
                    if (value == 'settings') onSettings();
                    if (value == 'sign-out') onSignOut();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: SizedBox(
                        width: 220,
                        child: Text(
                          email ?? 'Signed in',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    if (compact)
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded),
                            SizedBox(width: 10),
                            Text('Refresh'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined),
                          SizedBox(width: 10),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sign-out',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded),
                          SizedBox(width: 10),
                          Text('Sign out'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.snapshot,
    required this.email,
    required this.onEditAccount,
  });

  final DashboardSnapshot snapshot;
  final String? email;
  final ValueChanged<AccountBalance> onEditAccount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final accounts = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Your accounts',
              actionLabel: '${snapshot.accountBalances.length}',
            ),
            const SizedBox(height: 10),
            _AccountGrid(
              accounts: snapshot.accountBalances,
              onEdit: onEditAccount,
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 352,
                child: _WelcomeBalanceCard(snapshot: snapshot, email: email),
              ),
              const SizedBox(width: 20),
              Expanded(child: accounts),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeBalanceCard(snapshot: snapshot, email: email),
            const SizedBox(height: 18),
            accounts,
          ],
        );
      },
    );
  }
}

class _WelcomeBalanceCard extends StatelessWidget {
  const _WelcomeBalanceCard({required this.snapshot, required this.email});

  final DashboardSnapshot snapshot;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final rawName = email?.split('@').first.trim();
    final displayName = rawName == null || rawName.isEmpty ? 'there' : rawName;

    return Container(
      constraints: const BoxConstraints(minHeight: 216),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1A2E), Color(0xFF162447), Color(0xFF0D1220)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonEmerald.withValues(alpha: 0.16),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppTheme.neonViolet.withValues(alpha: 0.14),
            blurRadius: 36,
            spreadRadius: -10,
            offset: const Offset(-10, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $displayName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d').format(now),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.neonEmerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.neonEmerald.withValues(alpha: 0.32),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.neonEmerald,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'TOTAL BALANCE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _AnimatedMoney(
                value: snapshot.totalBalance,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Money in',
                  value: snapshot.monthIncome,
                  color: AppTheme.neonEmerald,
                  icon: Icons.south_west,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Money out',
                  value: snapshot.monthExpense,
                  color: AppTheme.neonRose,
                  icon: Icons.north_east,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.56),
                  ),
                ),
                _AnimatedMoney(
                  value: value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null)
          Container(
            constraints: const BoxConstraints(minWidth: 26, minHeight: 24),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.neonEmerald.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: AppTheme.neonEmerald.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              actionLabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.neonEmerald,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.title,
    required this.meta,
    required this.icon,
    required this.color,
  });

  final String title;
  final String meta;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                meta,
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
    );
  }
}

class _AccountGrid extends StatelessWidget {
  const _AccountGrid({required this.accounts, required this.onEdit});

  final List<AccountBalance> accounts;
  final ValueChanged<AccountBalance> onEdit;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const _EmptyCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No accounts found',
        subtitle: 'Accounts will appear here after signup or restore.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520
            ? 3
            : constraints.maxWidth >= 320
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: accounts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: columns == 1 ? 126 : 154,
          ),
          itemBuilder: (context, index) {
            return FadeSlideIn(
              index: index,
              child: _AccountCard(item: accounts[index], onEdit: onEdit),
            );
          },
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.item, required this.onEdit});

  final AccountBalance item;
  final ValueChanged<AccountBalance> onEdit;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.account.type) {
      'cash' => AppTheme.neonEmerald,
      'wallet' => AppTheme.neonCyan,
      'card' => AppTheme.neonAmber,
      _ => AppTheme.neonViolet,
    };

    final icon = switch (item.account.type) {
      'cash' => Icons.payments_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      'card' => Icons.credit_card,
      _ => Icons.account_balance_outlined,
    };

    return Semantics(
      button: true,
      label: 'Edit account ${item.account.name}',
      child: PressableScale(
        child: Container(
          key: ValueKey('account-card-${item.account.id}'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.nebula,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.14),
                blurRadius: 22,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => onEdit(item),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.2)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 15, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  item.account.type.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit account',
                            onPressed: () => onEdit(item),
                            icon: const Icon(Icons.more_horiz_rounded),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      _AnimatedMoney(
                        value: item.balance,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: item.balance < 0 ? AppTheme.neonRose : color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyStatsPanel extends StatelessWidget {
  const _MonthlyStatsPanel({
    required this.snapshot,
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DashboardSnapshot snapshot;
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month);
    final monthTransactions = snapshot.transactions.where((transaction) {
      final date = transaction.displayDate;
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    final income = monthTransactions
        .where((transaction) => transaction.type == 'income')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final expense = monthTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final net = income - expense;
    final savingsRate = income > 0 ? ((net / income) * 100).clamp(0, 100) : 0;

    // Cash carried forward from before this month: unlike income/expense
    // above, this includes loan and investment cash flows since it tracks
    // actual cash in hand, not just income/spending.
    const positiveTypes = {'income', 'borrow', 'receive', 'invest_return'};
    const negativeTypes = {'expense', 'lend', 'repay', 'invest'};
    final openingBalance = snapshot.transactions
        .where((transaction) => transaction.displayDate.isBefore(monthStart))
        .fold<double>(0, (total, transaction) {
          if (positiveTypes.contains(transaction.type)) {
            return total + transaction.amount;
          }
          if (negativeTypes.contains(transaction.type)) {
            return total - transaction.amount;
          }
          return total;
        });

    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final isCurrentMonth =
        selectedMonth.year == nowMonth.year &&
        selectedMonth.month == nowMonth.month;

    return Card(
      elevation: 10,
      shadowColor: AppTheme.neonCyan.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.neonCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppTheme.neonCyan,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly snapshot',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        formatMonth(selectedMonth),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Previous month',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Next month',
                  onPressed: isCurrentMonth ? null : onNext,
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Opening Balance',
                    value: openingBalance,
                    color: AppTheme.neonViolet,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Income',
                    value: income,
                    color: AppTheme.neonEmerald,
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Expense',
                    value: expense,
                    color: AppTheme.neonRose,
                    icon: Icons.trending_down,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Net',
                    value: net,
                    color: net >= 0 ? AppTheme.neonCyan : AppTheme.neonAmber,
                    icon: Icons.account_balance,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Savings rate',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${savingsRate.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.neonEmerald,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: savingsRate / 100,
                minHeight: 7,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppTheme.neonEmerald),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _AnimatedMoney(
              value: value,
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

class _DashboardTabBar extends StatelessWidget {
  const _DashboardTabBar({required this.activeTab, required this.onChanged});

  final DashboardTab activeTab;
  final ValueChanged<DashboardTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.nebula,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          _TabButton(
            key: const ValueKey('dashboard-tab-activity'),
            label: 'Activity',
            icon: Icons.list_alt,
            active: activeTab == DashboardTab.activity,
            onTap: () => onChanged(DashboardTab.activity),
          ),
          _TabButton(
            key: const ValueKey('dashboard-tab-ledger'),
            label: 'Ledger',
            icon: Icons.menu_book,
            active: activeTab == DashboardTab.ledger,
            onTap: () => onChanged(DashboardTab.ledger),
          ),
          _TabButton(
            key: const ValueKey('dashboard-tab-budget'),
            label: 'Budget',
            icon: Icons.bar_chart_rounded,
            active: activeTab == DashboardTab.budget,
            onTap: () => onChanged(DashboardTab.budget),
          ),
          _TabButton(
            key: const ValueKey('dashboard-tab-investments'),
            label: 'Invest',
            icon: Icons.trending_up,
            active: activeTab == DashboardTab.investments,
            onTap: () => onChanged(DashboardTab.investments),
          ),
        ],
      ),
    );
  }
}

class _MobileDashboardNav extends StatelessWidget {
  const _MobileDashboardNav({required this.activeTab, required this.onChanged});

  final DashboardTab activeTab;
  final ValueChanged<DashboardTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: NavigationBar(
        selectedIndex: activeTab.index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          onChanged(DashboardTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
              key: ValueKey('dashboard-tab-activity'),
            ),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.people_alt_outlined,
              key: ValueKey('dashboard-tab-ledger'),
            ),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.donut_small_outlined,
              key: ValueKey('dashboard-tab-budget'),
            ),
            selectedIcon: Icon(Icons.donut_small_rounded),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.trending_up_rounded,
              key: ValueKey('dashboard-tab-investments'),
            ),
            selectedIcon: Icon(Icons.show_chart_rounded),
            label: 'Invest',
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [AppTheme.neonEmerald, AppTheme.neonCyan],
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppTheme.neonEmerald.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: active
                      ? const Color(0xFF04231A)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active
                          ? const Color(0xFF04231A)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTabContent extends StatelessWidget {
  const _DashboardTabContent({
    required this.activeTab,
    required this.snapshot,
    required this.activityMode,
    required this.selectedDay,
    required this.selectedActivityMonth,
    required this.typeFilter,
    required this.activityAccountFilter,
    required this.activitySearchController,
    required this.activitySearchQuery,
    required this.activityVisibleLimit,
    required this.onLoadMoreActivity,
    required this.onActivityModeChanged,
    required this.onPreviousActivityDay,
    required this.onNextActivityDay,
    required this.onPickActivityDay,
    required this.onTodayActivity,
    required this.onPreviousActivityMonth,
    required this.onNextActivityMonth,
    required this.onPickActivityMonth,
    required this.onTypeFilterChanged,
    required this.onActivityAccountFilterChanged,
    required this.onActivitySearchChanged,
    required this.onClearActivitySearch,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
    required this.onAddPerson,
    required this.onLoanAction,
    required this.onViewPerson,
    required this.onEditPerson,
    required this.onDeletePerson,
    required this.selectedBudgetMonth,
    required this.onPreviousBudgetMonth,
    required this.onNextBudgetMonth,
    required this.onOpenBudget,
    required this.onNewInvestment,
    required this.onAddInvestmentFunds,
    required this.onRecordInvestmentReturn,
    required this.onDeleteInvestment,
  });

  final DashboardTab activeTab;
  final DashboardSnapshot snapshot;
  final ActivityMode activityMode;
  final DateTime selectedDay;
  final DateTime selectedActivityMonth;
  final String typeFilter;
  final String activityAccountFilter;
  final TextEditingController activitySearchController;
  final String activitySearchQuery;
  final int activityVisibleLimit;
  final VoidCallback onLoadMoreActivity;
  final ValueChanged<ActivityMode> onActivityModeChanged;
  final VoidCallback onPreviousActivityDay;
  final VoidCallback onNextActivityDay;
  final VoidCallback onPickActivityDay;
  final VoidCallback onTodayActivity;
  final VoidCallback onPreviousActivityMonth;
  final VoidCallback onNextActivityMonth;
  final VoidCallback onPickActivityMonth;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onActivityAccountFilterChanged;
  final ValueChanged<String> onActivitySearchChanged;
  final VoidCallback onClearActivitySearch;
  final ValueChanged<TransactionRecord> onEditTransaction;
  final ValueChanged<TransactionRecord> onDeleteTransaction;
  final VoidCallback onAddPerson;
  final void Function(LoanAction action, String? personId) onLoanAction;
  final ValueChanged<Person> onViewPerson;
  final ValueChanged<Person> onEditPerson;
  final ValueChanged<Person> onDeletePerson;
  final DateTime selectedBudgetMonth;
  final VoidCallback onPreviousBudgetMonth;
  final VoidCallback onNextBudgetMonth;
  final VoidCallback onOpenBudget;
  final VoidCallback onNewInvestment;
  final ValueChanged<Investment> onAddInvestmentFunds;
  final ValueChanged<Investment> onRecordInvestmentReturn;
  final ValueChanged<Investment> onDeleteInvestment;

  @override
  Widget build(BuildContext context) {
    return switch (activeTab) {
      DashboardTab.activity => _ActivityTab(
        snapshot: snapshot,
        mode: activityMode,
        selectedDay: selectedDay,
        selectedMonth: selectedActivityMonth,
        typeFilter: typeFilter,
        accountFilter: activityAccountFilter,
        searchController: activitySearchController,
        searchQuery: activitySearchQuery,
        visibleLimit: activityVisibleLimit,
        onLoadMore: onLoadMoreActivity,
        onModeChanged: onActivityModeChanged,
        onPreviousDay: onPreviousActivityDay,
        onNextDay: onNextActivityDay,
        onPickDay: onPickActivityDay,
        onToday: onTodayActivity,
        onPreviousMonth: onPreviousActivityMonth,
        onNextMonth: onNextActivityMonth,
        onPickMonth: onPickActivityMonth,
        onTypeFilterChanged: onTypeFilterChanged,
        onAccountFilterChanged: onActivityAccountFilterChanged,
        onSearchChanged: onActivitySearchChanged,
        onClearSearch: onClearActivitySearch,
        onEditTransaction: onEditTransaction,
        onDeleteTransaction: onDeleteTransaction,
      ),
      DashboardTab.ledger => _LedgerTab(
        snapshot: snapshot,
        onAddPerson: onAddPerson,
        onLoanAction: onLoanAction,
        onViewPerson: onViewPerson,
        onEditPerson: onEditPerson,
        onDeletePerson: onDeletePerson,
      ),
      DashboardTab.budget => _BudgetTab(
        snapshot: snapshot,
        selectedMonth: selectedBudgetMonth,
        onPreviousMonth: onPreviousBudgetMonth,
        onNextMonth: onNextBudgetMonth,
        onSetBudgets: onOpenBudget,
      ),
      DashboardTab.investments => _InvestmentsTab(
        snapshot: snapshot,
        onNewInvestment: onNewInvestment,
        onAddFunds: onAddInvestmentFunds,
        onRecordReturn: onRecordInvestmentReturn,
        onDelete: onDeleteInvestment,
      ),
    };
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.snapshot,
    required this.mode,
    required this.selectedDay,
    required this.selectedMonth,
    required this.typeFilter,
    required this.accountFilter,
    required this.searchController,
    required this.searchQuery,
    required this.visibleLimit,
    required this.onLoadMore,
    required this.onModeChanged,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickDay,
    required this.onToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonth,
    required this.onTypeFilterChanged,
    required this.onAccountFilterChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final DashboardSnapshot snapshot;
  final ActivityMode mode;
  final DateTime selectedDay;
  final DateTime selectedMonth;
  final String typeFilter;
  final String accountFilter;
  final TextEditingController searchController;
  final String searchQuery;
  final int visibleLimit;
  final VoidCallback onLoadMore;
  final ValueChanged<ActivityMode> onModeChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDay;
  final VoidCallback onToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onAccountFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<TransactionRecord> onEditTransaction;
  final ValueChanged<TransactionRecord> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final effectiveAccountFilter =
        snapshot.accounts.any((account) => account.id == accountFilter)
        ? accountFilter
        : 'all';
    final hasSearchQuery = searchQuery.trim().isNotEmpty;
    final hasAccountFilter = effectiveAccountFilter != 'all';
    final hasRefinement = hasSearchQuery || hasAccountFilter;
    const periodLabel = 'this period';
    final periodTransactions = snapshot.transactions
        .where(_matchesSelectedPeriod)
        .toList();
    final allFiltered = periodTransactions
        .where(_matchesTypeFilter)
        .where((transaction) {
          return _matchesAccountFilter(transaction, effectiveAccountFilter);
        })
        .where(_matchesSearch)
        .toList();
    final filtered = allFiltered.take(visibleLimit).toList();
    final hasMore = filtered.length < allFiltered.length;
    final groups = _groupTransactions(filtered);
    final moneyIn = allFiltered
        .where((transaction) => transaction.type == 'income')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final moneyOut = allFiltered
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final title = switch (mode) {
      ActivityMode.daily =>
        _isSameDay(selectedDay, DateTime.now())
            ? "Today's Activity"
            : 'Activity on ${DateFormat('MMM d').format(selectedDay)}',
      ActivityMode.monthly => 'Activity in ${formatMonth(selectedMonth)}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cash flow',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: _ActivityModeSwitcher(
                      mode: mode,
                      onChanged: onModeChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActivityPeriodNavigator(
                mode: mode,
                selectedDay: selectedDay,
                selectedMonth: selectedMonth,
                onPreviousDay: onPreviousDay,
                onNextDay: onNextDay,
                onPickDay: onPickDay,
                onToday: onToday,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth,
                onPickMonth: onPickMonth,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: 'Money in',
                      value: '+${formatMoney(moneyIn)}',
                      color: AppTheme.neonEmerald,
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActivitySummaryCard(
                      label: 'Money out',
                      value: '-${formatMoney(moneyOut)}',
                      color: AppTheme.neonRose,
                      icon: Icons.north_east,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 620;
            final search = _ActivitySearchField(
                  controller: searchController,
                  query: searchQuery,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
                account = _ActivityAccountFilter(
                  accounts: snapshot.accounts,
                  value: effectiveAccountFilter,
                  onChanged: onAccountFilterChanged,
                );

            if (sideBySide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: search),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: account),
                ],
              );
            }

            return Column(
              children: [search, const SizedBox(height: 10), account],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 10),
              child: Text(
                'Show',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipButton(
                    label: 'All',
                    value: 'all',
                    activeValue: typeFilter,
                    onChanged: onTypeFilterChanged,
                  ),
                  _FilterChipButton(
                    label: 'Income',
                    value: 'income',
                    activeValue: typeFilter,
                    color: AppTheme.neonEmerald,
                    onChanged: onTypeFilterChanged,
                  ),
                  _FilterChipButton(
                    label: 'Expense',
                    value: 'expense',
                    activeValue: typeFilter,
                    color: AppTheme.neonRose,
                    onChanged: onTypeFilterChanged,
                  ),
                  _FilterChipButton(
                    label: 'Transfer',
                    value: 'transfer',
                    activeValue: typeFilter,
                    color: AppTheme.neonCyan,
                    onChanged: onTypeFilterChanged,
                  ),
                  _FilterChipButton(
                    label: 'Loans',
                    value: 'loans',
                    activeValue: typeFilter,
                    color: AppTheme.neonAmber,
                    onChanged: onTypeFilterChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: title,
          actionLabel: hasRefinement
              ? '${allFiltered.length} match${allFiltered.length == 1 ? '' : 'es'}'
              : hasMore
              ? '${filtered.length} of ${allFiltered.length}'
              : '${allFiltered.length}',
        ),
        const SizedBox(height: 10),
        if (allFiltered.isEmpty)
          _EmptyCard(
            icon: Icons.receipt_long_outlined,
            title: 'No activity found',
            subtitle: hasRefinement
                ? 'No transaction matches the selected filters in $periodLabel.'
                : 'Transactions matching $periodLabel will show here.',
          )
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityGroupHeader(group: group),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < group.items.length;
                          index++
                        ) ...[
                          _TransactionTile(
                            transaction: group.items[index],
                            onEdit: onEditTransaction,
                            onDelete: onDeleteTransaction,
                          ),
                          if (index < group.items.length - 1)
                            const Divider(height: 1, indent: 66),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasMore) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(
                'Load ${allFiltered.length - filtered.length > 100 ? 100 : allFiltered.length - filtered.length} older',
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _matchesSelectedPeriod(TransactionRecord transaction) {
    final transactionDate = _dateOnly(_localDate(transaction.displayDate));

    return switch (mode) {
      ActivityMode.daily => _isSameDay(transactionDate, selectedDay),
      ActivityMode.monthly => _isSameMonth(transactionDate, selectedMonth),
    };
  }

  bool _matchesTypeFilter(TransactionRecord transaction) {
    return switch (typeFilter) {
      'income' => transaction.isIncomeLike,
      'expense' => transaction.isExpenseLike,
      'transfer' => transaction.type == 'transfer',
      'loans' => const {
        'lend',
        'borrow',
        'repay',
        'receive',
      }.contains(transaction.type),
      _ => true,
    };
  }

  bool _matchesAccountFilter(
    TransactionRecord transaction,
    String selectedAccountId,
  ) {
    if (selectedAccountId == 'all') return true;
    return transaction.fromAccountId == selectedAccountId ||
        transaction.toAccountId == selectedAccountId;
  }

  bool _matchesSearch(TransactionRecord transaction) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final accountNames = <String>[
      if (transaction.fromAccountId != null)
        _accountName(transaction.fromAccountId!),
      if (transaction.toAccountId != null)
        _accountName(transaction.toAccountId!),
    ];
    final personName = transaction.personId == null
        ? null
        : _personName(transaction.personId!);
    final investmentName = transaction.investmentId == null
        ? null
        : _investmentName(transaction.investmentId!);
    final haystack = [
      transaction.type,
      _transactionTypeLabel(transaction.type),
      transaction.category,
      transaction.note,
      personName,
      investmentName,
      ...accountNames,
      transaction.amount.toStringAsFixed(0),
      transaction.amount.toStringAsFixed(2),
      formatMoney(transaction.amount),
      DateFormat('MMM d, yyyy').format(transaction.displayDate),
    ].whereType<String>().join(' ').toLowerCase();

    return query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .every(haystack.contains);
  }

  String _accountName(String accountId) {
    for (final account in snapshot.accounts) {
      if (account.id == accountId) return account.name;
    }
    return '';
  }

  String _personName(String personId) {
    for (final person in snapshot.people) {
      if (person.id == personId) return person.name;
    }
    return '';
  }

  String _investmentName(String investmentId) {
    for (final investment in snapshot.investments) {
      if (investment.id == investmentId) return investment.name;
    }
    return '';
  }

  List<_TransactionGroup> _groupTransactions(
    List<TransactionRecord> transactions,
  ) {
    final sorted = [...transactions]
      ..sort(
        (a, b) =>
            _localDate(b.displayDate).compareTo(_localDate(a.displayDate)),
      );
    final byDay = <int, List<TransactionRecord>>{};

    for (final transaction in sorted) {
      final day = _dateOnly(_localDate(transaction.displayDate));
      byDay.putIfAbsent(day.millisecondsSinceEpoch, () => []).add(transaction);
    }

    final groups =
        byDay.entries
            .map(
              (entry) => _TransactionGroup(
                date: DateTime.fromMillisecondsSinceEpoch(entry.key),
                items: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return groups;
  }
}

class _ActivityModeSwitcher extends StatelessWidget {
  const _ActivityModeSwitcher({required this.mode, required this.onChanged});

  final ActivityMode mode;
  final ValueChanged<ActivityMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 336;
        return SegmentedButton<ActivityMode>(
          key: const ValueKey('activity-mode-switcher'),
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          selected: {mode},
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            ),
            textStyle: WidgetStatePropertyAll(
              Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          segments: [
            ButtonSegment<ActivityMode>(
              value: ActivityMode.daily,
              icon: compact ? null : const Icon(Icons.today_outlined),
              label: const Text('Daily'),
            ),
            ButtonSegment<ActivityMode>(
              value: ActivityMode.monthly,
              icon: compact ? null : const Icon(Icons.calendar_month_outlined),
              label: const Text('Monthly'),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityPeriodNavigator extends StatelessWidget {
  const _ActivityPeriodNavigator({
    required this.mode,
    required this.selectedDay,
    required this.selectedMonth,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickDay,
    required this.onToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonth,
  });

  final ActivityMode mode;
  final DateTime selectedDay;
  final DateTime selectedMonth;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDay;
  final VoidCallback onToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final nowMonth = _monthOnly(DateTime.now());
    final daily = mode == ActivityMode.daily;
    final atCurrentPeriod = daily
        ? _isSameDay(selectedDay, today)
        : _isSameMonth(selectedMonth, nowMonth);
    final label = daily
        ? atCurrentPeriod
              ? 'Today'
              : DateFormat('EEE, MMM d').format(selectedDay)
        : formatMonth(selectedMonth);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 336;
        return Container(
          padding: EdgeInsets.all(compact ? 8 : 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: daily ? 'Previous day' : 'Previous month',
                onPressed: daily ? onPreviousDay : onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: daily ? onPickDay : onPickMonth,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: daily ? 'Next day' : 'Next month',
                onPressed: atCurrentPeriod
                    ? null
                    : daily
                    ? onNextDay
                    : onNextMonth,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (daily && !atCurrentPeriod) ...[
                const SizedBox(width: 6),
                if (compact)
                  IconButton(
                    tooltip: 'Jump to today',
                    onPressed: onToday,
                    icon: const Icon(Icons.today),
                  )
                else
                  TextButton(onPressed: onToday, child: const Text('Today')),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActivitySearchField extends StatelessWidget {
  const _ActivitySearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search Activity',
        hintText: 'Category, note, account, person',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }
}

class _ActivityAccountFilter extends StatelessWidget {
  const _ActivityAccountFilter({
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Account',
        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All accounts')),
        ...accounts.map(
          (account) => DropdownMenuItem(
            value: account.id,
            child: Text(account.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

class _ActivityGroupHeader extends StatelessWidget {
  const _ActivityGroupHeader({required this.group});

  final _TransactionGroup group;

  @override
  Widget build(BuildContext context) {
    final title = _activityGroupTitle(group.date);
    final dateLabel = DateFormat('MMM d, yyyy').format(group.date);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${group.items.length}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                dateLabel,
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

class _TransactionGroup {
  const _TransactionGroup({required this.date, required this.items});

  final DateTime date;
  final List<TransactionRecord> items;
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.activeValue,
    required this.onChanged,
    this.color,
  });

  final String label;
  final String value;
  final String activeValue;
  final ValueChanged<String> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final active = value == activeValue;
    final activeColor = color ?? Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: activeColor.withValues(alpha: 0.16),
      checkmarkColor: activeColor,
      labelStyle: TextStyle(
        color: active ? activeColor : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      onSelected: (_) => onChanged(value),
    );
  }
}

class _LedgerTab extends StatelessWidget {
  const _LedgerTab({
    required this.snapshot,
    required this.onAddPerson,
    required this.onLoanAction,
    required this.onViewPerson,
    required this.onEditPerson,
    required this.onDeletePerson,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback onAddPerson;
  final void Function(LoanAction action, String? personId) onLoanAction;
  final ValueChanged<Person> onViewPerson;
  final ValueChanged<Person> onEditPerson;
  final ValueChanged<Person> onDeletePerson;

  @override
  Widget build(BuildContext context) {
    final openPersonIds = snapshot.ledgerEntries
        .map((entry) => entry.person.id)
        .toSet();
    final settledPeople = snapshot.people.where((person) {
      return !openPersonIds.contains(person.id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHeader(
          title: 'Ledger',
          meta: '${snapshot.people.length} people',
          icon: Icons.people_alt_outlined,
          color: AppTheme.neonAmber,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LedgerSummaryCard(
                label: 'To Receive',
                value: formatMoney(snapshot.totalToReceive),
                color: AppTheme.neonEmerald,
                icon: Icons.call_received,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LedgerSummaryCard(
                label: 'To Pay',
                value: formatMoney(snapshot.totalToPay),
                color: AppTheme.neonAmber,
                icon: Icons.call_made,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddPerson,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Person'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: snapshot.people.isEmpty
                    ? null
                    : () => onLoanAction(LoanAction.borrow, null),
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Borrow'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Give loan',
              onPressed: snapshot.people.isEmpty
                  ? null
                  : () => onLoanAction(LoanAction.lend, null),
              icon: const Icon(Icons.volunteer_activism_outlined),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SectionTitle(
          title: 'Open Balances',
          actionLabel: '${snapshot.ledgerEntries.length} active',
        ),
        const SizedBox(height: 8),
        if (snapshot.ledgerEntries.isEmpty)
          _EmptyLedger(hasPeople: snapshot.people.isNotEmpty)
        else
          ...snapshot.ledgerEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LedgerTile(
                entry: entry,
                onSettle: (action) => onLoanAction(action, entry.person.id),
                onView: () => onViewPerson(entry.person),
                onEdit: () => onEditPerson(entry.person),
                onDelete: () => onDeletePerson(entry.person),
              ),
            ),
          ),
        if (snapshot.people.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SectionTitle(
            title: 'People',
            actionLabel: '${snapshot.people.length} saved',
          ),
          const SizedBox(height: 8),
          if (settledPeople.isEmpty)
            const _SettledPeopleEmpty()
          else
            ...settledPeople.map(
              (person) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PersonDirectoryTile(
                  person: person,
                  onView: () => onViewPerson(person),
                  onEdit: () => onEditPerson(person),
                  onDelete: () => onDeletePerson(person),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _LedgerSummaryCard extends StatelessWidget {
  const _LedgerSummaryCard({
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 9),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
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

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    required this.entry,
    required this.onSettle,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final LedgerEntry entry;
  final ValueChanged<LoanAction> onSettle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final receive = entry.netBalance > 0;
    final color = receive ? AppTheme.neonEmerald : AppTheme.neonAmber;
    final status = receive ? 'They owe you' : 'You owe';
    final action = receive ? LoanAction.receive : LoanAction.repay;
    final actionLabel = receive ? 'Receive' : 'Repay';

    return Card(
      elevation: 10,
      shadowColor: color.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  foregroundColor: color,
                  child: Text(
                    entry.person.name.isEmpty
                        ? '?'
                        : entry.person.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.person.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        [
                          status,
                          if (entry.lastActivityAt != null)
                            'Last ${formatShortDate(entry.lastActivityAt!)}',
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
                Flexible(
                  child: Text(
                    '${receive ? '+' : '-'}${formatMoney(entry.netBalance.abs())}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                _PersonActionMenu(
                  onView: onView,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniLedgerValue(
                    label: 'They owe',
                    value: formatMoney(entry.theyOwe),
                    color: AppTheme.neonEmerald,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniLedgerValue(
                    label: 'You owe',
                    value: formatMoney(entry.youOwe),
                    color: AppTheme.neonAmber,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => onSettle(action),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size(84, 48),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonDirectoryTile extends StatelessWidget {
  const _PersonDirectoryTile({
    required this.person,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Person person;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (person.phone?.isNotEmpty == true) person.phone!,
      if (person.note?.isNotEmpty == true) person.note!,
      if (person.phone?.isNotEmpty != true && person.note?.isNotEmpty != true)
        'No open balance',
    ].join(' | ');

    return Semantics(
      button: true,
      label: 'View history for ${person.name}',
      child: Card(
        elevation: 8,
        shadowColor: AppTheme.neonViolet.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.neonCyan,
                  child: Text(
                    person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        details,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PersonActionMenu(
                  onView: onView,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonActionMenu extends StatelessWidget {
  const _PersonActionMenu({
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Person actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'history':
            onView();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined),
              SizedBox(width: 10),
              Text('History'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: AppTheme.neonRose),
              SizedBox(width: 10),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettledPeopleEmpty extends StatelessWidget {
  const _SettledPeopleEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      icon: Icons.info_outline,
      message: 'Every saved person currently has an open balance.',
      color: AppTheme.neonCyan,
    );
  }
}

class _MiniLedgerValue extends StatelessWidget {
  const _MiniLedgerValue({
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
        color: color.withValues(alpha: 0.08),
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

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.hasPeople});

  final bool hasPeople;

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: hasPeople
          ? Icons.balance_outlined
          : Icons.person_add_alt_1_outlined,
      title: hasPeople ? 'No open balances' : 'No people yet',
      subtitle: hasPeople
          ? 'Borrowing and lending balances will show here.'
          : 'Add a person before tracking loans.',
    );
  }
}

class _BudgetTab extends StatelessWidget {
  const _BudgetTab({
    required this.snapshot,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSetBudgets,
  });

  final DashboardSnapshot snapshot;
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSetBudgets;

  @override
  Widget build(BuildContext context) {
    final rows = _budgetRowsForMonth(snapshot, selectedMonth);
    final totals = _BudgetTotals.fromRows(rows);
    final atCurrentMonth = _isSameMonth(selectedMonth, DateTime.now());
    final totalColor = totals.totalBudget <= 0
        ? AppTheme.neonCyan
        : totals.remaining < 0
        ? AppTheme.neonRose
        : totals.percent >= 0.8
        ? AppTheme.neonAmber
        : AppTheme.neonEmerald;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHeader(
          title: 'Budget',
          meta: formatMonth(selectedMonth),
          icon: Icons.donut_small_outlined,
          color: AppTheme.neonCyan,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Previous month',
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: Text(
                        formatMonth(selectedMonth),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Next month',
                    onPressed: atCurrentMonth ? null : onNextMonth,
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSetBudgets,
                  icon: const Icon(Icons.tune),
                  label: const Text('Set Budgets'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BudgetSummaryTile(
                label: 'Budget',
                value: formatMoney(totals.totalBudget),
                color: AppTheme.neonCyan,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BudgetSummaryTile(
                label: 'Spent',
                value: formatMoney(totals.totalSpent),
                color: AppTheme.neonRose,
                icon: Icons.north_east,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BudgetTotalCard(totals: totals, color: totalColor),
        const SizedBox(height: 14),
        _SectionTitle(title: 'Category Budgets', actionLabel: '${rows.length}'),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _EmptyCard(
            icon: Icons.bar_chart_rounded,
            title: 'No budgets yet',
            subtitle: 'Set a monthly budget or add expenses to see categories.',
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BudgetRowTile(row: row),
            ),
          ),
      ],
    );
  }
}

class _BudgetSummaryTile extends StatelessWidget {
  const _BudgetSummaryTile({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

class _BudgetTotalCard extends StatelessWidget {
  const _BudgetTotalCard({required this.totals, required this.color});

  final _BudgetTotals totals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentLabel = (totals.percent * 100).round();
    final status = totals.totalBudget <= 0
        ? 'No budget set'
        : totals.remaining >= 0
        ? 'Remaining ${formatMoney(totals.remaining)}'
        : 'Over ${formatMoney(totals.remaining.abs())}';

    return Card(
      elevation: 10,
      shadowColor: color.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Progress',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  totals.totalBudget > 0 ? '$percentLabel%' : '-',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: totals.totalBudget > 0 ? totals.percent : 0,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent ${formatMoney(totals.totalSpent)}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  status,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
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

class _BudgetRowTile extends StatelessWidget {
  const _BudgetRowTile({required this.row});

  final _BudgetRowData row;

  @override
  Widget build(BuildContext context) {
    final color = row.budget <= 0
        ? AppTheme.neonCyan
        : row.remaining < 0
        ? AppTheme.neonRose
        : row.percent >= 0.8
        ? AppTheme.neonAmber
        : AppTheme.neonEmerald;
    final status = row.budget <= 0
        ? 'No budget'
        : row.remaining >= 0
        ? 'Remaining ${formatMoney(row.remaining)}'
        : 'Over ${formatMoney(row.remaining.abs())}';

    return Card(
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sell_outlined, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.category,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Spent ${formatMoney(row.spent)} / Budget ${formatMoney(row.budget)}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  row.budget > 0 ? '${(row.percent * 100).round()}%' : '-',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: row.budget > 0 ? row.percent : 0,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                status,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRowData {
  const _BudgetRowData({
    required this.category,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percent,
  });

  final String category;
  final double budget;
  final double spent;
  final double remaining;
  final double percent;
}

class _BudgetTotals {
  const _BudgetTotals({
    required this.totalBudget,
    required this.totalSpent,
    required this.remaining,
    required this.percent,
  });

  final double totalBudget;
  final double totalSpent;
  final double remaining;
  final double percent;

  factory _BudgetTotals.fromRows(List<_BudgetRowData> rows) {
    final totalBudget = rows.fold<double>(
      0,
      (total, row) => total + row.budget,
    );
    final totalSpent = rows.fold<double>(0, (total, row) => total + row.spent);
    final rawPercent = totalBudget > 0 ? totalSpent / totalBudget : 0.0;
    final percent = rawPercent > 1 ? 1.0 : rawPercent;

    return _BudgetTotals(
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      remaining: totalBudget - totalSpent,
      percent: percent,
    );
  }
}

List<_BudgetRowData> _budgetRowsForMonth(
  DashboardSnapshot snapshot,
  DateTime month,
) {
  final budgetByCategory = <String, double>{};
  for (final budget in snapshot.budgets) {
    if (!_isSameMonth(budget.month, month)) continue;
    final category = budget.category.trim().isEmpty
        ? 'Uncategorized'
        : budget.category.trim();
    budgetByCategory[category] = budget.amount;
  }

  final spentByCategory = <String, double>{};
  for (final transaction in snapshot.transactions) {
    if (transaction.type != 'expense') continue;
    if (!_isSameMonth(transaction.displayDate, month)) continue;

    final category = (transaction.category ?? '').trim().isEmpty
        ? 'Uncategorized'
        : transaction.category!.trim();
    spentByCategory[category] =
        (spentByCategory[category] ?? 0) + transaction.amount;
  }

  final categories = <String>{
    ...budgetByCategory.keys,
    ...spentByCategory.keys,
  }.toList()..sort((a, b) => a.compareTo(b));

  return categories.map((category) {
    final budget = budgetByCategory[category] ?? 0;
    final spent = spentByCategory[category] ?? 0;
    final rawPercent = budget > 0 ? spent / budget : 0.0;
    final percent = rawPercent > 1 ? 1.0 : rawPercent;

    return _BudgetRowData(
      category: category,
      budget: budget,
      spent: spent,
      remaining: budget - spent,
      percent: percent,
    );
  }).toList();
}

class _InvestmentsTab extends StatelessWidget {
  const _InvestmentsTab({
    required this.snapshot,
    required this.onNewInvestment,
    required this.onAddFunds,
    required this.onRecordReturn,
    required this.onDelete,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback onNewInvestment;
  final ValueChanged<Investment> onAddFunds;
  final ValueChanged<Investment> onRecordReturn;
  final ValueChanged<Investment> onDelete;

  @override
  Widget build(BuildContext context) {
    final cards = _investmentCards(snapshot);
    final summary = _InvestmentPortfolioSummary.fromSnapshot(snapshot);

    if (snapshot.investments.isEmpty) {
      return _EmptyInvestmentState(onNewInvestment: onNewInvestment);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHeader(
          title: 'Investments',
          meta: '${summary.activeCount} active',
          icon: Icons.trending_up_rounded,
          color: AppTheme.neonCyan,
        ),
        const SizedBox(height: 14),
        _InvestmentSummaryCard(summary: summary),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onNewInvestment,
            icon: const Icon(Icons.add),
            label: const Text('New Investment'),
          ),
        ),
        const SizedBox(height: 14),
        _SectionTitle(
          title: 'Investments',
          actionLabel: '${snapshot.investments.length}',
        ),
        const SizedBox(height: 10),
        ...cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InvestmentTile(
              card: card,
              onAddFunds: () => onAddFunds(card.investment),
              onRecordReturn: () => onRecordReturn(card.investment),
              onDelete: () => onDelete(card.investment),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyInvestmentState extends StatelessWidget {
  const _EmptyInvestmentState({required this.onNewInvestment});

  final VoidCallback onNewInvestment;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      key: const ValueKey('investments-empty-state'),
      icon: Icons.trending_up,
      title: 'No investments yet',
      message:
          'Track invested capital and returned money without mixing it into income or expenses.',
      color: AppTheme.neonCyan,
      actionLabel: 'Add First Investment',
      onAction: onNewInvestment,
    );
  }
}

class _InvestmentSummaryCard extends StatelessWidget {
  const _InvestmentSummaryCard({required this.summary});

  final _InvestmentPortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final profit = summary.netProfitLoss >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neonCyan.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.neonCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Investment Portfolio',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.neonCyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (summary.totalInvested > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (profit ? AppTheme.neonEmerald : AppTheme.neonRose)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${profit ? '+' : ''}${summary.roi.toStringAsFixed(1)}% ROI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: profit ? AppTheme.neonEmerald : AppTheme.neonRose,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: 2,
                childAspectRatio: constraints.maxWidth < 340 ? 2.1 : 2.7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _InvestmentMetric(
                    label: 'Active',
                    value: '${summary.activeCount}',
                    color: AppTheme.neonCyan,
                  ),
                  _InvestmentMetric(
                    label: 'Invested',
                    value: formatMoney(summary.totalInvested),
                    color: AppTheme.neonViolet,
                  ),
                  _InvestmentMetric(
                    label: 'Returns',
                    value: formatMoney(summary.totalReturns),
                    color: AppTheme.neonEmerald,
                  ),
                  _InvestmentMetric(
                    label: 'Profit / Loss',
                    value:
                        '${profit ? '+' : '-'}${formatMoney(summary.netProfitLoss.abs())}',
                    color: profit ? AppTheme.neonEmerald : AppTheme.neonRose,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvestmentMetric extends StatelessWidget {
  const _InvestmentMetric({
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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

class _InvestmentTile extends StatelessWidget {
  const _InvestmentTile({
    required this.card,
    required this.onAddFunds,
    required this.onRecordReturn,
    required this.onDelete,
  });

  final _InvestmentCardData card;
  final VoidCallback onAddFunds;
  final VoidCallback onRecordReturn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = card.investment.status == 'active';
    final profit = card.profitLoss >= 0;
    final accent = active
        ? AppTheme.neonCyan
        : profit
        ? AppTheme.neonEmerald
        : AppTheme.neonRose;

    return Card(
      elevation: 10,
      shadowColor: accent.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.investment.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _InvestmentStatusBadge(
                            label: card.investment.status,
                            color: active
                                ? AppTheme.neonCyan
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (card.investment.description != null)
                        Text(
                          card.investment.description!,
                          overflow: TextOverflow.ellipsis,
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
                PopupMenuButton<String>(
                  tooltip: 'Investment actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: AppTheme.neonRose,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.neonRose),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniInvestmentValue(
                    label: 'Invested',
                    value: formatMoney(card.totalInvested),
                    color: AppTheme.neonCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInvestmentValue(
                    label: 'Returns',
                    value: formatMoney(card.totalReturns),
                    color: AppTheme.neonEmerald,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInvestmentValue(
                    label: 'P/L',
                    value:
                        '${profit ? '+' : '-'}${formatMoney(card.profitLoss.abs())}',
                    color: profit ? AppTheme.neonEmerald : AppTheme.neonRose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                card.totalInvested > 0
                    ? '${profit ? '+' : ''}${card.roi.toStringAsFixed(1)}% ROI'
                    : 'No funds yet',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: profit ? AppTheme.neonEmerald : AppTheme.neonRose,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (active)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddFunds,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Funds'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onRecordReturn,
                      icon: const Icon(Icons.call_received),
                      label: const Text('Return'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Closed investment',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

class _InvestmentStatusBadge extends StatelessWidget {
  const _InvestmentStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MiniInvestmentValue extends StatelessWidget {
  const _MiniInvestmentValue({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentPortfolioSummary {
  const _InvestmentPortfolioSummary({
    required this.activeCount,
    required this.totalInvested,
    required this.totalReturns,
    required this.netProfitLoss,
    required this.roi,
  });

  final int activeCount;
  final double totalInvested;
  final double totalReturns;
  final double netProfitLoss;
  final double roi;

  factory _InvestmentPortfolioSummary.fromSnapshot(DashboardSnapshot snapshot) {
    final totalInvested = snapshot.transactions
        .where((transaction) => transaction.type == 'invest')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final totalReturns = snapshot.transactions
        .where((transaction) => transaction.type == 'invest_return')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final netProfitLoss = totalReturns - totalInvested;

    return _InvestmentPortfolioSummary(
      activeCount: snapshot.investments
          .where((investment) => investment.status == 'active')
          .length,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      netProfitLoss: netProfitLoss,
      roi: totalInvested > 0 ? (netProfitLoss / totalInvested) * 100 : 0,
    );
  }
}

class _InvestmentCardData {
  const _InvestmentCardData({
    required this.investment,
    required this.totalInvested,
    required this.totalReturns,
    required this.profitLoss,
    required this.roi,
  });

  final Investment investment;
  final double totalInvested;
  final double totalReturns;
  final double profitLoss;
  final double roi;
}

List<_InvestmentCardData> _investmentCards(DashboardSnapshot snapshot) {
  final cards = snapshot.investments.map((investment) {
    final transactions = snapshot.transactions.where((transaction) {
      return transaction.investmentId == investment.id;
    });
    final totalInvested = transactions
        .where((transaction) => transaction.type == 'invest')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final totalReturns = transactions
        .where((transaction) => transaction.type == 'invest_return')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final profitLoss = totalReturns - totalInvested;

    return _InvestmentCardData(
      investment: investment,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      profitLoss: profitLoss,
      roi: totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0,
    );
  }).toList();

  cards.sort((a, b) {
    final aActive = a.investment.status == 'active';
    final bActive = b.investment.status == 'active';
    if (aActive != bActive) return aActive ? -1 : 1;
    return b.investment.createdAt.compareTo(a.investment.createdAt);
  });

  return cards;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final TransactionRecord transaction;
  final ValueChanged<TransactionRecord>? onEdit;
  final ValueChanged<TransactionRecord>? onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpenseLike;
    final isIncome = transaction.isIncomeLike;
    final color = isExpense
        ? AppTheme.neonRose
        : isIncome
        ? AppTheme.neonEmerald
        : AppTheme.neonCyan;
    final signedAmount = isExpense ? -transaction.amount : transaction.amount;

    final leading = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_iconFor(transaction.type), color: color, size: 20),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          transaction.category ?? transaction.type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          [
            formatShortDate(transaction.displayDate),
            if (transaction.note != null) transaction.note!,
          ].join(' | '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final amount = Text(
      formatMoney(signedAmount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
      ),
    );
    final hasActions = onEdit != null || onDelete != null;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit == null ? null : () => onEdit!(transaction),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;
              final actions = hasActions
                  ? _TransactionActionsMenu(
                      transaction: transaction,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    )
                  : null;

              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        ?actions,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 50),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: amount,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 118),
                    child: amount,
                  ),
                  if (actions != null) ...[const SizedBox(width: 2), actions],
                ],
              );
            },
          ),
        ),
      ),
    );

    final semanticContent = Semantics(
      button: onEdit != null,
      label:
          '${transaction.category ?? transaction.type}, ${formatMoney(signedAmount)}, ${formatShortDate(transaction.displayDate)}',
      hint: onEdit != null
          ? 'Open to edit. More transaction actions are available.'
          : null,
      child: content,
    );

    if (!hasActions) return semanticContent;

    final direction = onEdit != null && onDelete != null
        ? DismissDirection.horizontal
        : onEdit != null
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;

    return Semantics(
      customSemanticsActions: {
        if (onEdit != null)
          const CustomSemanticsAction(label: 'Edit transaction'): () {
            onEdit!(transaction);
          },
        if (onDelete != null)
          const CustomSemanticsAction(label: 'Delete transaction'): () {
            onDelete!(transaction);
          },
      },
      child: Dismissible(
        key: ValueKey('transaction-swipe-${transaction.id}'),
        direction: direction,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.28,
          DismissDirection.endToStart: 0.28,
        },
        movementDuration: const Duration(milliseconds: 180),
        resizeDuration: null,
        background: const _SwipeActionBackground(
          alignment: Alignment.centerLeft,
          color: AppTheme.neonCyan,
          icon: Icons.edit_outlined,
          label: 'Edit',
        ),
        secondaryBackground: const _SwipeActionBackground(
          alignment: Alignment.centerRight,
          color: AppTheme.neonRose,
          icon: Icons.delete_outline,
          label: 'Delete',
        ),
        confirmDismiss: (swipeDirection) async {
          if (swipeDirection == DismissDirection.startToEnd) {
            onEdit?.call(transaction);
          } else if (swipeDirection == DismissDirection.endToStart) {
            onDelete?.call(transaction);
          }
          return false;
        },
        child: semanticContent,
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
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
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final leftAligned = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: leftAligned
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (!leftAligned) ...[
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white, size: 20),
          if (leftAligned) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionActionsMenu extends StatelessWidget {
  const _TransactionActionsMenu({
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final TransactionRecord transaction;
  final ValueChanged<TransactionRecord>? onEdit;
  final ValueChanged<TransactionRecord>? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Transaction actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call(transaction);
        if (value == 'delete') onDelete?.call(transaction);
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: AppTheme.neonRose, size: 18),
                const SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: AppTheme.neonRose)),
              ],
            ),
          ),
      ],
    );
  }
}

DateTime _localDate(DateTime value) {
  return value.isUtc ? value.toLocal() : value;
}

DateTime _dateOnly(DateTime value) {
  final local = _localDate(value);
  return DateTime(local.year, local.month, local.day);
}

DateTime _monthOnly(DateTime value) {
  final local = _localDate(value);
  return DateTime(local.year, local.month);
}

bool _isSameDay(DateTime a, DateTime b) {
  final first = _dateOnly(a);
  final second = _dateOnly(b);
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool _isSameMonth(DateTime a, DateTime b) {
  final first = _monthOnly(a);
  final second = _monthOnly(b);
  return first.year == second.year && first.month == second.month;
}

String _activityGroupTitle(DateTime date) {
  final today = _dateOnly(DateTime.now());
  final day = _dateOnly(date);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE').format(day);
}

String _transactionTypeLabel(String type) {
  return switch (type) {
    'income' => 'Income',
    'expense' => 'Expense',
    'transfer' => 'Transfer',
    'lend' => 'Loan Given',
    'borrow' => 'Borrowed',
    'repay' => 'Loan Repaid',
    'receive' => 'Loan Received',
    'invest' => 'Investment',
    'invest_return' => 'Investment Return',
    _ => type,
  };
}

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet({
    required this.onIncome,
    required this.onExpense,
    required this.onTransfer,
    required this.onInvestment,
  });

  final VoidCallback onIncome;
  final VoidCallback onExpense;
  final VoidCallback onTransfer;
  final VoidCallback onInvestment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.nebula,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: AppTheme.glassBorderStrong),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonEmerald.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBorderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    _SheetActionButton(
                      label: 'Money In',
                      icon: Icons.south_west,
                      color: AppTheme.neonEmerald,
                      onPressed: onIncome,
                    ),
                    const SizedBox(height: 10),
                    _SheetActionButton(
                      label: 'Money Out',
                      icon: Icons.north_east,
                      color: AppTheme.neonRose,
                      onPressed: onExpense,
                    ),
                    const SizedBox(height: 10),
                    _SheetActionButton(
                      label: 'Transfer',
                      icon: Icons.swap_horiz,
                      color: AppTheme.neonCyan,
                      onPressed: onTransfer,
                    ),
                    const SizedBox(height: 10),
                    _SheetActionButton(
                      label: 'New Investment',
                      icon: Icons.trending_up,
                      color: AppTheme.neonAmber,
                      onPressed: onInvestment,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textOnDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      title: title,
      message: subtitle,
      compact: true,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 1120
            ? 1120.0
            : constraints.maxWidth;
        final horizontal = constraints.maxWidth < 360 ? 12.0 : 20.0;
        final columns = width >= 760
            ? 3
            : width >= 480
            ? 2
            : 1;

        return Semantics(
          label: 'Loading dashboard',
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: const ValueKey('dashboard-loading-skeleton'),
              width: width,
              height: constraints.maxHeight,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
                children: [
                  const AppSkeletonBox(height: 170),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 92,
                    ),
                    itemBuilder: (context, index) {
                      return const AppSkeletonBox(height: 92);
                    },
                  ),
                  const SizedBox(height: 14),
                  const AppSkeletonBox(height: 178),
                  const SizedBox(height: 14),
                  const AppSkeletonBox(height: 220),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppErrorPanel(
            key: const ValueKey('dashboard-error-state'),
            title: 'Could not load dashboard',
            message: 'Check your connection, then try loading your data again.',
            onRetry: () {
              onRetry();
            },
          ),
        ),
      ),
    );
  }
}
