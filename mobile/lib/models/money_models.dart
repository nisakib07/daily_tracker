import '../core/date_times.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final DateTime createdAt;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: _string(json['id']),
      name: _string(json['name']),
      type: _string(json['type']),
      createdAt: _dateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Person {
  const Person({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? note;
  final DateTime createdAt;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: _string(json['id']),
      name: _string(json['name']),
      phone: _nullableString(json['phone']),
      note: _nullableString(json['note']),
      createdAt: _dateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Investment {
  const Investment({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String status;
  final DateTime createdAt;

  factory Investment.fromJson(Map<String, dynamic> json) {
    return Investment(
      id: _string(json['id']),
      name: _string(json['name']),
      description: _nullableString(json['description']),
      status: _string(json['status'], fallback: 'active'),
      createdAt: _dateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.personId,
    this.investmentId,
    this.category,
    this.note,
    this.date,
    required this.occurredAt,
    required this.createdAt,
    this.pending = false,
  });

  /// Id prefix of transactions that were created offline and don't exist on
  /// the server yet, so they have no real id to edit or delete by.
  static const pendingIdPrefix = 'pending-';

  final String id;
  final String type;
  final double amount;
  final String? fromAccountId;
  final String? toAccountId;
  final String? personId;
  final String? investmentId;
  final String? category;
  final String? note;
  final DateTime? date;
  final DateTime occurredAt;
  final DateTime createdAt;

  /// Whether this row shows a change saved on this device that hasn't
  /// synced yet. Never stored; set only when pending changes are applied.
  final bool pending;

  /// False for a transaction created offline that the server hasn't
  /// assigned an id to yet.
  bool get existsOnServer => !id.startsWith(pendingIdPrefix);

  // occurred_at is the timestamp written by the app and preserves the
  // selected transaction day across timezone conversions. The legacy date
  // column can be a server-local date and may drift by one day.
  DateTime get displayDate => occurredAt;

  bool get isIncomeLike {
    return const {
      'income',
      'borrow',
      'receive',
      'invest_return',
    }.contains(type);
  }

  bool get isExpenseLike {
    return const {'expense', 'lend', 'repay', 'invest'}.contains(type);
  }

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final occurredAt = _dateTime(json['occurred_at']);
    return TransactionRecord(
      id: _string(json['id']),
      type: _string(json['type']),
      amount: _double(json['amount']),
      fromAccountId: _nullableString(json['from_account_id']),
      toAccountId: _nullableString(json['to_account_id']),
      personId: _nullableString(json['person_id']),
      investmentId: _nullableString(json['investment_id']),
      category: _nullableString(json['category']),
      note: _nullableString(json['note']),
      date: _nullableDateTime(json['date']),
      occurredAt: occurredAt,
      createdAt: _nullableDateTime(json['created_at']) ?? occurredAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'person_id': personId,
      'investment_id': investmentId,
      'category': category,
      'note': note,
      'date': date?.toIso8601String(),
      'occurred_at': toSupabaseTimestamp(occurredAt),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.month,
    required this.category,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime month;
  final String category;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Budget.fromJson(Map<String, dynamic> json) {
    final createdAt = _dateTime(json['created_at']);
    return Budget(
      id: _string(json['id']),
      month: _dateTime(json['month']),
      category: _string(json['category']),
      amount: _double(json['amount']),
      createdAt: createdAt,
      updatedAt: _nullableDateTime(json['updated_at']) ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month.toIso8601String(),
      'category': category,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateTime(Object? value) {
  return parseLocalDateTime(value);
}

DateTime? _nullableDateTime(Object? value) {
  return parseNullableLocalDateTime(value);
}
