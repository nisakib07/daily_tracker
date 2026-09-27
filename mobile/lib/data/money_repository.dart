import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/date_times.dart';
import '../models/money_models.dart';
import 'loan_position.dart';
import 'offline_mutation_queue.dart';

class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final Account account;
  final double balance;
}

class LedgerEntry {
  const LedgerEntry({
    required this.person,
    required this.youOwe,
    required this.theyOwe,
    required this.netBalance,
    required this.lastActivityAt,
  });

  final Person person;
  final double youOwe;
  final double theyOwe;
  final double netBalance;
  final DateTime? lastActivityAt;
}

class TransactionCursor {
  const TransactionCursor({required this.occurredAt, required this.id});

  final DateTime occurredAt;
  final String id;
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<TransactionRecord> items;
  final TransactionCursor? nextCursor;
  final bool hasMore;
}

class DashboardServerSummary {
  const DashboardServerSummary({
    required this.month,
    required this.accountBalances,
    required this.monthIncome,
    required this.monthExpense,
    required this.transactionCount,
  });

  final DateTime month;
  final Map<String, double> accountBalances;
  final double monthIncome;
  final double monthExpense;
  final int transactionCount;

  factory DashboardServerSummary.fromJson(Map<String, dynamic> json) {
    return DashboardServerSummary(
      month:
          DateTime.tryParse(json['month']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      accountBalances: Map<String, dynamic>.from(
        json['account_balances'] as Map? ?? const {},
      ).map((key, value) => MapEntry(key, _number(value))),
      monthIncome: _number(json['month_income']),
      monthExpense: _number(json['month_expense']),
      transactionCount: _number(json['transaction_count']).round(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month.toIso8601String(),
      'account_balances': accountBalances,
      'month_income': monthIncome,
      'month_expense': monthExpense,
      'transaction_count': transactionCount,
    };
  }
}

abstract interface class AdvancedMoneyDataSource {
  Future<TransactionPage> fetchTransactionPage({
    TransactionCursor? before,
    int limit = 100,
  });

  Future<DashboardServerSummary?> fetchServerSummary(DateTime month);
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.accounts,
    required this.people,
    required this.investments,
    required this.transactions,
    required this.budgets,
    this.serverSummary,
  });

  final List<Account> accounts;
  final List<Person> people;
  final List<Investment> investments;
  final List<TransactionRecord> transactions;
  final List<Budget> budgets;
  final DashboardServerSummary? serverSummary;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    return DashboardSnapshot(
      accounts: rows('accounts').map(Account.fromJson).toList(),
      people: rows('people').map(Person.fromJson).toList(),
      investments: rows('investments').map(Investment.fromJson).toList(),
      transactions: rows(
        'transactions',
      ).map(TransactionRecord.fromJson).toList(),
      budgets: rows('budgets').map(Budget.fromJson).toList(),
      serverSummary: json['server_summary'] is Map
          ? DashboardServerSummary.fromJson(
              Map<String, dynamic>.from(json['server_summary'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accounts': accounts.map((item) => item.toJson()).toList(),
      'people': people.map((item) => item.toJson()).toList(),
      'investments': investments.map((item) => item.toJson()).toList(),
      'transactions': transactions.map((item) => item.toJson()).toList(),
      'budgets': budgets.map((item) => item.toJson()).toList(),
      'server_summary': serverSummary?.toJson(),
    };
  }

  List<AccountBalance> get accountBalances {
    final remoteBalances = serverSummary?.accountBalances;
    final balances = accounts.map((account) {
      final balance =
          remoteBalances?[account.id] ??
          transactions.fold<double>(0, (total, transaction) {
            var next = total;
            if (transaction.toAccountId == account.id) {
              next += transaction.amount;
            }
            if (transaction.fromAccountId == account.id) {
              next -= transaction.amount;
            }
            return next;
          });
      return AccountBalance(account: account, balance: balance);
    }).toList();

    balances.sort((a, b) {
      final order = {'cash': 0, 'wallet': 1, 'card': 2};
      return (order[a.account.type] ?? 99).compareTo(
        order[b.account.type] ?? 99,
      );
    });

    return balances;
  }

  double get totalBalance {
    return accountBalances.fold(0, (total, item) => total + item.balance);
  }

  double get monthIncome => _serverMonthlyTotal('income');

  double get monthExpense => _serverMonthlyTotal('expense');

  double _serverMonthlyTotal(String type) {
    final now = DateTime.now();
    final summary = serverSummary;
    if (summary != null &&
        summary.month.year == now.year &&
        summary.month.month == now.month) {
      return type == 'income' ? summary.monthIncome : summary.monthExpense;
    }
    return _monthlyTotal(type);
  }

  double _monthlyTotal(String type) {
    final now = DateTime.now();
    return transactions
        .where((transaction) {
          final date = transaction.displayDate;
          return transaction.type == type &&
              date.year == now.year &&
              date.month == now.month;
        })
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  List<TransactionRecord> get recentTransactions {
    return transactions.take(12).toList();
  }

  List<LedgerEntry> get ledgerEntries {
    final entries = people
        .map((person) {
          final position = LoanPosition.from(
            transactions.where(
              (transaction) => transaction.personId == person.id,
            ),
          );
          return LedgerEntry(
            person: person,
            youOwe: position.youOwe,
            theyOwe: position.theyOwe,
            netBalance: position.netBalance,
            lastActivityAt: position.lastActivityAt,
          );
        })
        .where((entry) {
          return entry.netBalance != 0;
        })
        .toList();

    entries.sort((a, b) {
      final amountCompare = b.netBalance.abs().compareTo(a.netBalance.abs());
      if (amountCompare != 0) return amountCompare;
      final aTime = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return entries;
  }

  double get totalToReceive {
    return ledgerEntries.fold(
      0,
      (total, entry) => entry.netBalance > 0 ? total + entry.netBalance : total,
    );
  }

  double get totalToPay {
    return ledgerEntries.fold(
      0,
      (total, entry) =>
          entry.netBalance < 0 ? total + entry.netBalance.abs() : total,
    );
  }
}

abstract interface class MoneyDataSource {
  Future<DashboardSnapshot> fetchDashboard();

  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  });

  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  });

  Future<void> createTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  });

  Future<void> createPerson({
    required String name,
    String? phone,
    String? note,
  });

  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
  });

  Future<void> deletePerson(String personId);

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required double adjustmentAmount,
    required bool addMoney,
    String? note,
  });

  Future<void> createLoanTransaction({
    required String type,
    required double amount,
    required String accountId,
    required String personId,
    required DateTime occurredAt,
    String? note,
  });

  Future<void> createInvestment({
    required String name,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? description,
    String? note,
  });

  Future<void> addInvestmentFunds({
    required String investmentId,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? note,
  });

  Future<void> recordInvestmentReturn({
    required String investmentId,
    required double amount,
    required String toAccountId,
    required DateTime occurredAt,
    required bool closeInvestment,
    String? note,
  });

  Future<void> updateTransaction({
    required TransactionRecord transaction,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? toAccountId,
    String? personId,
    String? category,
    String? note,
  });

  Future<void> replaceBudgetsForMonth({
    required DateTime month,
    required Map<String, double> budgets,
  });

  Future<void> clearBudgetsForMonth(DateTime month);

  Future<void> deleteInvestment(String investmentId);

  Future<void> deleteTransaction(String transactionId);
}

class MoneyRepository
    implements
        MoneyDataSource,
        AdvancedMoneyDataSource,
        IdempotentMoneyMutationExecutor {
  MoneyRepository(this.client);

  final SupabaseClient client;
  bool? _advancedRpcAvailable;
  bool? _mutationRpcAvailable;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final accountsFuture = client
        .from('accounts')
        .select('id,name,type,created_at')
        .order('created_at');
    final peopleFuture = client
        .from('people')
        .select('id,name,phone,note,created_at')
        .order('name');
    final investmentsFuture = client
        .from('investments')
        .select('id,name,description,status,created_at')
        .order('created_at', ascending: false);
    final transactionsFuture = _fetchAllTransactions();
    final budgetsFuture = client
        .from('budgets')
        .select('id,month,category,amount,created_at,updated_at')
        .order('month', ascending: false)
        .order('category');
    final summaryFuture = fetchServerSummary(DateTime.now());

    final accountRows = await accountsFuture;
    final personRows = await peopleFuture;
    final investmentRows = await investmentsFuture;
    final transactions = await transactionsFuture;
    final budgetRows = await budgetsFuture;
    final serverSummary = await summaryFuture;

    final accounts = accountRows
        .map((row) => Account.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    final people = personRows
        .map((row) => Person.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    final investments = investmentRows
        .map(
          (row) => Investment.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final budgets = budgetRows
        .map((row) => Budget.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();

    return DashboardSnapshot(
      accounts: accounts,
      people: people,
      investments: investments,
      transactions: transactions,
      budgets: budgets,
      serverSummary: serverSummary,
    );
  }

  Future<List<TransactionRecord>> _fetchAllTransactions() async {
    const pageSize = 1000;
    final transactions = <TransactionRecord>[];
    var from = 0;

    while (true) {
      final rows = await client
          .from('transactions')
          .select(
            'id,type,amount,from_account_id,to_account_id,person_id,'
            'investment_id,category,note,occurred_at,created_at',
          )
          .order('occurred_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + pageSize - 1);

      final page = rows
          .map(
            (row) => TransactionRecord.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

      transactions.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }

    return transactions;
  }

  @override
  Future<void> createMoneyIn({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add a transaction.');
    }

    await client.from('transactions').insert({
      'type': 'income',
      'amount': amount,
      'from_account_id': null,
      'to_account_id': accountId,
      'person_id': null,
      'investment_id': null,
      'category': category,
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> createMoneyOut({
    required double amount,
    required String accountId,
    required String category,
    required DateTime occurredAt,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add a transaction.');
    }

    await client.from('transactions').insert({
      'type': 'expense',
      'amount': amount,
      'from_account_id': accountId,
      'to_account_id': null,
      'person_id': null,
      'investment_id': null,
      'category': category,
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> createTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add a transfer.');
    }

    await client.from('transactions').insert({
      'type': 'transfer',
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'person_id': null,
      'investment_id': null,
      'category': 'Transfer',
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> createPerson({
    required String name,
    String? phone,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add a person.');
    }

    await client.from('people').insert({
      'name': name.trim(),
      'phone': _blankToNull(phone),
      'note': _blankToNull(note),
      'user_id': userId,
    });
  }

  @override
  Future<void> updatePerson({
    required String personId,
    required String name,
    String? phone,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to update a person.');
    }

    await client
        .from('people')
        .update({
          'name': name.trim(),
          'phone': _blankToNull(phone),
          'note': _blankToNull(note),
        })
        .eq('id', personId)
        .eq('user_id', userId);
  }

  @override
  Future<void> deletePerson(String personId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to delete a person.');
    }

    await client
        .from('people')
        .delete()
        .eq('id', personId)
        .eq('user_id', userId);
  }

  @override
  Future<void> updateAccount({
    required String accountId,
    required String name,
    required double adjustmentAmount,
    required bool addMoney,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to update an account.');
    }

    await client
        .from('accounts')
        .update({'name': name.trim()})
        .eq('id', accountId)
        .eq('user_id', userId);

    if (adjustmentAmount <= 0) return;

    await client.from('transactions').insert({
      'type': addMoney ? 'income' : 'expense',
      'amount': adjustmentAmount,
      'from_account_id': addMoney ? null : accountId,
      'to_account_id': addMoney ? accountId : null,
      'person_id': null,
      'investment_id': null,
      'category': 'Balance Adjustment',
      'note':
          _blankToNull(note) ??
          'Manual balance ${addMoney ? 'increase' : 'decrease'}',
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(DateTime.now()),
    });
  }

  @override
  Future<void> createLoanTransaction({
    required String type,
    required double amount,
    required String accountId,
    required String personId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add a loan entry.');
    }

    final moneyIn = type == 'borrow' || type == 'receive';

    await client.from('transactions').insert({
      'type': type,
      'amount': amount,
      'from_account_id': moneyIn ? null : accountId,
      'to_account_id': moneyIn ? accountId : null,
      'person_id': personId,
      'investment_id': null,
      'category': _loanCategory(type),
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> createInvestment({
    required String name,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? description,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add an investment.');
    }

    final investmentRow = await client
        .from('investments')
        .insert({
          'name': name.trim(),
          'description': _blankToNull(description),
          'status': 'active',
          'user_id': userId,
        })
        .select('id')
        .single();

    final investmentId = investmentRow['id'].toString();

    await client.from('transactions').insert({
      'type': 'invest',
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': null,
      'person_id': null,
      'investment_id': investmentId,
      'category': 'Investment',
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> addInvestmentFunds({
    required String investmentId,
    required double amount,
    required String fromAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to add funds.');
    }

    await client.from('transactions').insert({
      'type': 'invest',
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': null,
      'person_id': null,
      'investment_id': investmentId,
      'category': 'Investment',
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });
  }

  @override
  Future<void> recordInvestmentReturn({
    required String investmentId,
    required double amount,
    required String toAccountId,
    required DateTime occurredAt,
    required bool closeInvestment,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to record a return.');
    }

    await client.from('transactions').insert({
      'type': 'invest_return',
      'amount': amount,
      'from_account_id': null,
      'to_account_id': toAccountId,
      'person_id': null,
      'investment_id': investmentId,
      'category': 'Investment Return',
      'note': _blankToNull(note),
      'user_id': userId,
      'occurred_at': toSupabaseTimestamp(occurredAt),
    });

    if (!closeInvestment) return;

    await client
        .from('investments')
        .update({'status': 'closed'})
        .eq('id', investmentId)
        .eq('user_id', userId);
  }

  @override
  Future<void> updateTransaction({
    required TransactionRecord transaction,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? toAccountId,
    String? personId,
    String? category,
    String? note,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'You must be signed in to update a transaction.',
      );
    }

    final type = transaction.type;
    final moneyIn = transaction.isIncomeLike;
    final transfer = type == 'transfer';
    final loan = const {'borrow', 'lend', 'repay', 'receive'}.contains(type);
    final investment = const {'invest', 'invest_return'}.contains(type);

    final update = <String, Object?>{
      'amount': amount,
      'note': _blankToNull(note),
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'person_id': investment ? transaction.personId : _blankToNull(personId),
      'category': transfer
          ? 'Transfer'
          : loan
          ? _loanCategory(type)
          : _blankToNull(category) ?? transaction.category,
    };

    if (transfer) {
      update['from_account_id'] = accountId;
      update['to_account_id'] = toAccountId;
    } else if (moneyIn) {
      update['from_account_id'] = null;
      update['to_account_id'] = accountId;
    } else {
      update['from_account_id'] = accountId;
      update['to_account_id'] = null;
    }

    final updatedRows = await client
        .from('transactions')
        .update(update)
        .eq('id', transaction.id)
        .select('id');

    if (updatedRows.isEmpty) {
      throw const PostgrestException(
        message: 'No matching transaction was updated.',
        code: 'P0002',
      );
    }
  }

  @override
  Future<void> replaceBudgetsForMonth({
    required DateTime month,
    required Map<String, double> budgets,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to save budgets.');
    }

    final monthKey = _monthKey(month);
    await client
        .from('budgets')
        .delete()
        .eq('month', monthKey)
        .eq('user_id', userId);

    final rows = budgets.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .map(
          (entry) => {
            'month': monthKey,
            'category': entry.key.trim(),
            'amount': entry.value,
            'user_id': userId,
            'updated_at': toSupabaseTimestamp(DateTime.now()),
          },
        )
        .toList();

    if (rows.isEmpty) return;

    await client.from('budgets').insert(rows);
  }

  @override
  Future<void> clearBudgetsForMonth(DateTime month) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to clear budgets.');
    }

    await client
        .from('budgets')
        .delete()
        .eq('month', _monthKey(month))
        .eq('user_id', userId);
  }

  @override
  Future<void> deleteInvestment(String investmentId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('You must be signed in to delete investments.');
    }

    await client
        .from('transactions')
        .delete()
        .eq('investment_id', investmentId)
        .eq('user_id', userId);

    await client
        .from('investments')
        .delete()
        .eq('id', investmentId)
        .eq('user_id', userId);
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'You must be signed in to delete a transaction.',
      );
    }

    final deletedRows = await client
        .from('transactions')
        .delete()
        .eq('id', transactionId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw const PostgrestException(
        message: 'No matching transaction was deleted.',
        code: 'P0002',
      );
    }
  }

  @override
  Future<TransactionPage> fetchTransactionPage({
    TransactionCursor? before,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 250);
    if (_advancedRpcAvailable == false) {
      return _fetchTransactionPageDirect(before: before, limit: safeLimit);
    }
    try {
      final result = await client.rpc(
        'money_master_transaction_page',
        params: {
          'p_before': before == null
              ? null
              : toSupabaseTimestamp(before.occurredAt),
          'p_before_id': before?.id,
          'p_limit': safeLimit,
        },
      );
      _advancedRpcAvailable = true;
      return _transactionPageFromRows(result, safeLimit);
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) rethrow;
      _advancedRpcAvailable = false;
      return _fetchTransactionPageDirect(before: before, limit: safeLimit);
    }
  }

  Future<TransactionPage> _fetchTransactionPageDirect({
    TransactionCursor? before,
    required int limit,
  }) async {
    var query = client
        .from('transactions')
        .select(
          'id,type,amount,from_account_id,to_account_id,person_id,'
          'investment_id,category,note,occurred_at,created_at',
        );
    if (before != null) {
      // Matches the tie-break in the money_master_transaction_page RPC: rows
      // sharing the exact same occurred_at as the cursor must still be
      // ordered by id, or same-timestamp transactions can be skipped between
      // pages.
      final beforeAt = toSupabaseTimestamp(before.occurredAt);
      query = query.or(
        'occurred_at.lt.$beforeAt,'
        'and(occurred_at.eq.$beforeAt,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('occurred_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return _transactionPageFromRows(rows, limit);
  }

  TransactionPage _transactionPageFromRows(Object? value, int limit) {
    final rows = value is List ? value : const [];
    final items = rows
        .whereType<Map>()
        .map(
          (row) => TransactionRecord.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
    final last = items.lastOrNull;
    return TransactionPage(
      items: items,
      nextCursor: last == null
          ? null
          : TransactionCursor(occurredAt: last.occurredAt, id: last.id),
      hasMore: items.length == limit,
    );
  }

  @override
  Future<DashboardServerSummary?> fetchServerSummary(DateTime month) async {
    if (_advancedRpcAvailable == false) return null;
    try {
      final result = await client.rpc(
        'money_master_dashboard_summary',
        params: {'p_month': _monthKey(month)},
      );
      if (result is! Map) return null;
      final rows = result['account_balances'];
      final balances = <String, double>{};
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          balances[row['account_id'].toString()] = _number(row['balance']);
        }
      }
      _advancedRpcAvailable = true;
      return DashboardServerSummary(
        month: DateTime(month.year, month.month),
        accountBalances: balances,
        monthIncome: _number(result['month_income']),
        monthExpense: _number(result['month_expense']),
        transactionCount: _number(result['transaction_count']).round(),
      );
    } on PostgrestException catch (error) {
      if (_isMissingRpc(error)) {
        _advancedRpcAvailable = false;
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> executeMutation(QueuedMoneyMutation mutation) async {
    if (_mutationRpcAvailable == false) {
      await _executeLegacyMutation(mutation);
      return;
    }
    try {
      await client.rpc(
        'apply_money_mutation',
        params: {
          'p_mutation_id': mutation.id,
          'p_kind': mutation.kind,
          'p_payload': mutation.payload,
        },
      );
      _mutationRpcAvailable = true;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) rethrow;
      _mutationRpcAvailable = false;
      await _executeLegacyMutation(mutation);
    }
  }

  Future<void> _executeLegacyMutation(QueuedMoneyMutation mutation) async {
    final payload = mutation.payload;
    switch (mutation.kind) {
      case 'money_in':
        await createMoneyIn(
          amount: _number(payload['amount']),
          accountId: payload['account_id'].toString(),
          category: payload['category'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          note: payload['note']?.toString(),
        );
      case 'money_out':
        await createMoneyOut(
          amount: _number(payload['amount']),
          accountId: payload['account_id'].toString(),
          category: payload['category'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          note: payload['note']?.toString(),
        );
      case 'transfer':
        await createTransfer(
          amount: _number(payload['amount']),
          fromAccountId: payload['from_account_id'].toString(),
          toAccountId: payload['to_account_id'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          note: payload['note']?.toString(),
        );
      case 'create_person':
        await createPerson(
          name: payload['name'].toString(),
          phone: payload['phone']?.toString(),
          note: payload['note']?.toString(),
        );
      case 'update_person':
        await updatePerson(
          personId: payload['person_id'].toString(),
          name: payload['name'].toString(),
          phone: payload['phone']?.toString(),
          note: payload['note']?.toString(),
        );
      case 'delete_person':
        await deletePerson(payload['person_id'].toString());
      case 'update_account':
        await updateAccount(
          accountId: payload['account_id'].toString(),
          name: payload['name'].toString(),
          adjustmentAmount: _number(payload['adjustment_amount']),
          addMoney: payload['add_money'] == true,
          note: payload['note']?.toString(),
        );
      case 'loan':
        await createLoanTransaction(
          type: payload['type'].toString(),
          amount: _number(payload['amount']),
          accountId: payload['account_id'].toString(),
          personId: payload['person_id'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          note: payload['note']?.toString(),
        );
      case 'create_investment':
        await createInvestment(
          name: payload['name'].toString(),
          amount: _number(payload['amount']),
          fromAccountId: payload['from_account_id'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          description: payload['description']?.toString(),
          note: payload['note']?.toString(),
        );
      case 'add_investment_funds':
        await addInvestmentFunds(
          investmentId: payload['investment_id'].toString(),
          amount: _number(payload['amount']),
          fromAccountId: payload['from_account_id'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          note: payload['note']?.toString(),
        );
      case 'investment_return':
        await recordInvestmentReturn(
          investmentId: payload['investment_id'].toString(),
          amount: _number(payload['amount']),
          toAccountId: payload['to_account_id'].toString(),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          closeInvestment: payload['close_investment'] == true,
          note: payload['note']?.toString(),
        );
      case 'update_transaction':
        final transaction = TransactionRecord.fromJson(
          Map<String, dynamic>.from(payload['transaction'] as Map),
        );
        await updateTransaction(
          transaction: transaction,
          amount: _number(payload['amount']),
          occurredAt: _payloadDate(payload, 'occurred_at'),
          accountId: payload['account_id'].toString(),
          toAccountId: payload['to_account_id']?.toString(),
          personId: payload['person_id']?.toString(),
          category: payload['category']?.toString(),
          note: payload['note']?.toString(),
        );
      case 'replace_budgets':
        final values = Map<String, dynamic>.from(
          payload['budgets'] as Map? ?? const {},
        ).map((key, value) => MapEntry(key, _number(value)));
        await replaceBudgetsForMonth(
          month: _payloadDate(payload, 'month'),
          budgets: values,
        );
      case 'clear_budgets':
        await clearBudgetsForMonth(_payloadDate(payload, 'month'));
      case 'delete_investment':
        await deleteInvestment(payload['investment_id'].toString());
      case 'delete_transaction':
        try {
          await deleteTransaction(payload['transaction_id'].toString());
        } on PostgrestException catch (error) {
          if (error.message != 'No matching transaction was deleted.') rethrow;
        }
      default:
        throw ArgumentError.value(
          mutation.kind,
          'mutation.kind',
          'Unsupported money mutation',
        );
    }
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _loanCategory(String type) {
  return switch (type) {
    'borrow' => 'Borrowed Money',
    'lend' => 'Loan Given',
    'repay' => 'Loan Repayment',
    'receive' => 'Loan Received Back',
    _ => 'Loan',
  };
}

String _monthKey(DateTime month) {
  final year = month.year.toString().padLeft(4, '0');
  final value = month.month.toString().padLeft(2, '0');
  return '$year-$value-01';
}

bool _isMissingRpc(PostgrestException error) {
  return error.code == 'PGRST202' || error.code == '42883';
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _payloadDate(Map<String, dynamic> payload, String key) {
  return DateTime.parse(payload[key].toString());
}
