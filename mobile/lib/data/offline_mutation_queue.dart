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
  final List<QueuedMoneyMutation> _failed = [];

  int get pendingCount => _mutations.length;

  /// Mutations that failed with a non-retryable error during drain (e.g. the
  /// referenced row was deleted before the queued mutation could be applied).
  /// Kept out of the active queue so one bad mutation can't block every
  /// mutation queued after it.
  int get failedCount => _failed.length;

  List<QueuedMoneyMutation> get failedMutations => List.unmodifiable(_failed);

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
        // A non-retryable failure means this specific mutation can never
        // succeed (e.g. it references a row deleted in the meantime) — drop
        // it into the failed list rather than leaving it stuck at the head
        // of the queue, which would block every mutation queued after it.
        _mutations.removeAt(0);
        _failed.add(mutation);
        await _persist();
        continue;
      }

      _mutations.removeAt(0);
      applied++;
      await _persist();
    }

    return applied;
  }

  Future<void> _read() async {
    _mutations
      ..clear()
      ..addAll(await _readList(_key));
    _failed
      ..clear()
      ..addAll(await _readList(_failedKey));
  }

  Future<List<QueuedMoneyMutation>> _readList(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final rows = jsonDecode(raw);
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (row) =>
                QueuedMoneyMutation.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    } catch (_) {
      await _store.delete(key);
      return const [];
    }
  }

  Future<void> _persist() async {
    await _writeList(_key, _mutations);
    await _writeList(_failedKey, _failed);
  }

  Future<void> _writeList(
    String key,
    List<QueuedMoneyMutation> mutations,
  ) async {
    if (mutations.isEmpty) {
      await _store.delete(key);
      return;
    }
    await _store.write(
      key,
      jsonEncode(mutations.map((item) => item.toJson()).toList()),
    );
  }

  String get _failedKey => '$_key.failed';
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
