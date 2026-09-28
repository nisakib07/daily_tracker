import 'dart:convert';

import 'package:intl/intl.dart';

import '../core/date_times.dart';
import '../models/money_models.dart';
import 'money_repository.dart';

/// Builds the files behind Settings > Your data. Both are made from the last
/// snapshot synced with the server, never from changes still waiting to sync.

String exportFileDate(DateTime now) => DateFormat('yyyy-MM-dd').format(now);

/// A file ready for the share sheet. The name travels separately from the
/// bytes because an in-memory XFile drops its name on Android and iOS.
class ExportFile {
  const ExportFile({
    required this.name,
    required this.mimeType,
    required this.contents,
  });

  final String name;
  final String mimeType;
  final String contents;

  List<int> get bytes => utf8.encode(contents);
}

/// Which days a CSV export covers: all time, one month, or a date range.
class ExportPeriod {
  const ExportPeriod.all() : this._(null, null);

  ExportPeriod.month(DateTime month)
    : this._(
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1, 0),
      );

  ExportPeriod.range(DateTime first, DateTime last)
    : this._(_day(first), _day(last));

  const ExportPeriod._(this.first, this.last);

  /// The first and last day included, or null for all time.
  final DateTime? first;
  final DateTime? last;

  bool includes(DateTime when) {
    final from = first;
    final until = last;
    if (from == null || until == null) return true;
    final day = _day(when);
    return !day.isBefore(from) && !day.isAfter(until);
  }

  bool get _isWholeMonth {
    final from = first;
    return from != null &&
        from.day == 1 &&
        last == DateTime(from.year, from.month + 1, 0);
  }

  /// For the file name: "2026-09", "2026-09-01-to-2026-09-15", or null for
  /// all time.
  String? get fileLabel {
    final from = first;
    final until = last;
    if (from == null || until == null) return null;
    if (_isWholeMonth) return DateFormat('yyyy-MM').format(from);
    final day = DateFormat('yyyy-MM-dd');
    return from == until
        ? day.format(from)
        : '${day.format(from)}-to-${day.format(until)}';
  }

  /// For messages: "September 2026", "1 Sep - 15 Sep 2026", "all time".
  String get description {
    final from = first;
    final until = last;
    if (from == null || until == null) return 'all time';
    if (_isWholeMonth) return DateFormat('MMMM yyyy').format(from);
    final day = DateFormat('d MMM yyyy');
    return from == until
        ? day.format(from)
        : '${day.format(from)} - ${day.format(until)}';
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// A spreadsheet of the transactions in [period], newest first, with names
/// instead of ids. Starts with a byte-order mark so Excel reads ৳ and Bangla
/// names as UTF-8.
String transactionsCsv(
  DashboardSnapshot snapshot, {
  ExportPeriod period = const ExportPeriod.all(),
}) {
  String nameIn<T>(
    List<T> items,
    String? id,
    String Function(T) idOf,
    String Function(T) nameOf,
  ) {
    if (id == null) return '';
    for (final item in items) {
      if (idOf(item) == id) return nameOf(item);
    }
    return '';
  }

  String account(String? id) => nameIn<Account>(
    snapshot.accounts,
    id,
    (item) => item.id,
    (item) => item.name,
  );

  final rows = <List<String>>[
    const [
      'Date',
      'Time',
      'Type',
      'Amount',
      'Category',
      'From Account',
      'To Account',
      'Person',
      'Investment',
      'Note',
    ],
    for (final transaction in snapshot.transactions)
      if (period.includes(transaction.displayDate))
        [
          DateFormat('yyyy-MM-dd').format(transaction.displayDate),
          DateFormat('HH:mm').format(transaction.displayDate),
          _typeLabel(transaction.type),
          transaction.amount.toStringAsFixed(2),
          transaction.category ?? '',
          account(transaction.fromAccountId),
          account(transaction.toAccountId),
          nameIn<Person>(
            snapshot.people,
            transaction.personId,
            (item) => item.id,
            (item) => item.name,
          ),
          nameIn<Investment>(
            snapshot.investments,
            transaction.investmentId,
            (item) => item.id,
            (item) => item.name,
          ),
          transaction.note ?? '',
        ],
  ];

  return '﻿${rows.map((row) => row.map(_csvField).join(',')).join('\r\n')}\r\n';
}

/// A full backup in the same shape the Money Master website exports and
/// imports (Settings > Export Data / Import Data there), so it can be
/// restored from the website. Rows carry [userId] because the website's
/// import writes them back as they are, and row-level security only accepts
/// rows owned by the signed-in user. Investments are included too; the
/// website ignores what it doesn't know.
String backupJson(
  DashboardSnapshot snapshot, {
  required String userId,
  required DateTime exportedAt,
  List<String> customIncomeCategories = const [],
  List<String> customExpenseCategories = const [],
}) {
  String at(DateTime value) => toSupabaseTimestamp(value);

  final backup = {
    'version': 1,
    'exportedAt': at(exportedAt),
    'source': 'money_master_mobile',
    'data': {
      'accounts': [
        for (final account in snapshot.accounts)
          {
            'id': account.id,
            'name': account.name,
            'type': account.type,
            'created_at': at(account.createdAt),
            'user_id': userId,
          },
      ],
      'people': [
        for (final person in snapshot.people)
          {
            'id': person.id,
            'name': person.name,
            'phone': person.phone,
            'note': person.note,
            'created_at': at(person.createdAt),
            'user_id': userId,
          },
      ],
      'investments': [
        for (final investment in snapshot.investments)
          {
            'id': investment.id,
            'name': investment.name,
            'description': investment.description,
            'status': investment.status,
            'created_at': at(investment.createdAt),
            'user_id': userId,
          },
      ],
      'transactions': [
        for (final transaction in snapshot.transactions)
          {
            'id': transaction.id,
            'type': transaction.type,
            'amount': transaction.amount,
            'from_account_id': transaction.fromAccountId,
            'to_account_id': transaction.toAccountId,
            'person_id': transaction.personId,
            'investment_id': transaction.investmentId,
            'category': transaction.category,
            'note': transaction.note,
            'occurred_at': at(transaction.occurredAt),
            'created_at': at(transaction.createdAt),
            'user_id': userId,
          },
      ],
      'budgets': [
        for (final budget in snapshot.budgets)
          {
            'id': budget.id,
            'month': DateFormat('yyyy-MM-dd').format(budget.month),
            'category': budget.category,
            'amount': budget.amount,
            'created_at': at(budget.createdAt),
            'updated_at': at(budget.updatedAt),
            'user_id': userId,
          },
      ],
      'customCategories': {
        'income': customIncomeCategories,
        'expense': customExpenseCategories,
      },
    },
  };
  return const JsonEncoder.withIndent('  ').convert(backup);
}

String _typeLabel(String type) {
  return switch (type) {
    'income' => 'Income',
    'expense' => 'Expense',
    'transfer' => 'Transfer',
    'lend' => 'Loan given',
    'borrow' => 'Borrowed',
    'repay' => 'Loan repaid',
    'receive' => 'Repayment received',
    'invest' => 'Investment',
    'invest_return' => 'Investment return',
    _ => type,
  };
}

/// Quotes a field when needed (RFC 4180), and stops text that starts like a
/// formula from being run by spreadsheet apps.
String _csvField(String value) {
  var field = value;
  if (field.isNotEmpty && '=+-@'.contains(field[0])) field = "'$field";
  if (field.contains(RegExp('[",\r\n]'))) {
    field = '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
