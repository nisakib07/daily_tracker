// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'network_error.dart';
import 'secure_cache_store.dart';

class QueuedMoneyMutation {
  const QueuedMoneyMutation({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory QueuedMoneyMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMoneyMutation(
      id: json['id'].toString(),
      kind: json['kind'].toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

abstract interface class IdempotentMoneyMutationExecutor {
  Future<void> executeMutation(QueuedMoneyMutation mutation);
}

class OfflineMutationQueue {
  OfflineMutationQueue({
    required DashboardCacheStore store,
    required String key,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _store = store,
       _key = key,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final DashboardCacheStore _store;
  final String _key;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<void>? _loadFuture;
  Future<int>? _drainFuture;
  final List<QueuedMoneyMutation> _mutations = [];

  int get pendingCount => _mutations.length;

  QueuedMoneyMutation create(String kind, Map<String, dynamic> payload) {
    return QueuedMoneyMutation(
      id: _uuid.v4(),
      kind: kind,
      payload: payload,
      createdAt: _clock(),
    );
  }

  Future<void> load() {
    return _loadFuture ??= _read();
  }

  Future<void> enqueue(QueuedMoneyMutation mutation) async {
    await load();
    if (_mutations.any((item) => item.id == mutation.id)) return;
    _mutations.add(mutation);
    await _persist();
  }

  Future<int> drain(IdempotentMoneyMutationExecutor executor) async {
    final inFlight = _drainFuture;
    if (inFlight != null) return inFlight;

    final future = _drain(executor);
    _drainFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_drainFuture, future)) _drainFuture = null;
    }
  }

  Future<int> _drain(IdempotentMoneyMutationExecutor executor) async {
    await load();
    var applied = 0;

    while (_mutations.isNotEmpty) {
      final mutation = _mutations.first;
      try {
        await executor.executeMutation(mutation);
      } catch (error) {
        if (isRetryableMutationError(error)) return applied;
        rethrow;
      }

      _mutations.removeAt(0);
      applied++;
      await _persist();
    }

    return applied;
  }

  Future<void> _read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return;

    try {
      final rows = jsonDecode(raw);
      if (rows is! List) return;
      _mutations
        ..clear()
        ..addAll(
          rows.whereType<Map>().map(
            (row) =>
                QueuedMoneyMutation.fromJson(Map<String, dynamic>.from(row)),
          ),
        );
    } catch (_) {
      _mutations.clear();
      await _store.delete(_key);
    }
  }

  Future<void> _persist() async {
    if (_mutations.isEmpty) {
      await _store.delete(_key);
      return;
    }
    await _store.write(
      _key,
      jsonEncode(_mutations.map((item) => item.toJson()).toList()),
    );
  }
}

bool isRetryableMutationError(Object error) {
  if (error is TimeoutException ||
      isIoNetworkError(error) ||
      error is ClientException) {
    return true;
  }

  if (error is AuthException || error is PostgrestException) return false;
  return false;
}
