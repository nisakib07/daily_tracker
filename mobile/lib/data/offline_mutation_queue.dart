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
    this.attempts = 0,
    this.failureReason,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Failed sync attempts that weren't caused by being offline.
  final int attempts;

  /// Why the last attempt failed, worded for the user.
  final String? failureReason;

  QueuedMoneyMutation failedWith(Object error) {
    final nextAttempts = attempts + 1;
    return _copy(
      attempts: nextAttempts,
      failureReason: describeMutationFailure(error, attempts: nextAttempts),
    );
  }

  QueuedMoneyMutation resetForRetry() => _copy(attempts: 0);

  QueuedMoneyMutation _copy({required int attempts, String? failureReason}) {
    return QueuedMoneyMutation(
      id: id,
      kind: kind,
      payload: payload,
      createdAt: createdAt,
      attempts: attempts,
      failureReason: failureReason,
    );
  }

  factory QueuedMoneyMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMoneyMutation(
      id: json['id'].toString(),
      kind: json['kind'].toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      failureReason: json['failure_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'attempts': attempts,
      'failure_reason': failureReason,
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

  /// How many times a mutation may fail for reasons other than being offline
  /// (server errors, an expired session) before it is moved to the failed
  /// list for the user to retry or discard.
  static const maxAttempts = 5;

  int get pendingCount => _mutations.length;

  /// Mutations that can't succeed as written (e.g. the referenced row was
  /// deleted before the queued mutation could be applied), or that kept
  /// failing. Kept out of the active queue so one bad mutation can't block
  /// every mutation queued after it, and shown to the user, who decides
  /// whether to retry or discard each one.
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
        // Offline: keep everything queued, in order, for the next drain.
        if (isRetryableMutationError(error)) return applied;

        final attempted = mutation.failedWith(error);
        if (!isPermanentMutationError(error) &&
            attempted.attempts < maxAttempts) {
          // A server hiccup or expired session. Stop here rather than skip
          // ahead, since later mutations may depend on this one (a loan for
          // a person created offline), and try again on the next drain.
          _mutations[0] = attempted;
          await _persist();
          return applied;
        }

        // It can never succeed as written, or keeps failing: move it aside
        // so the mutations behind it can sync, and leave it for the user.
        _mutations.removeAt(0);
        _failed.add(attempted);
        await _persist();
        continue;
      }

      _mutations.removeAt(0);
      applied++;
      await _persist();
    }

    return applied;
  }

  /// Moves failed mutations back to the front of the queue, in their
  /// original order, for the next drain. With [id], only that one.
  Future<void> retryFailed({String? id}) async {
    await load();
    await _waitForDrain();
    bool matches(QueuedMoneyMutation item) => id == null || item.id == id;
    final retrying = _failed.where(matches).map((item) {
      return item.resetForRetry();
    }).toList();
    if (retrying.isEmpty) return;
    _failed.removeWhere(matches);
    _mutations.insertAll(0, retrying);
    await _persist();
  }

  Future<void> discardFailed(String id) async {
    await load();
    _failed.removeWhere((item) => item.id == id);
    await _persist();
  }

  /// Lets an in-flight drain finish before the head of the queue changes;
  /// drain removes whatever is first once each mutation completes.
  Future<void> _waitForDrain() async {
    while (_drainFuture != null) {
      try {
        await _drainFuture;
      } catch (_) {
        // The drain's own caller handles its errors.
      }
    }
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

/// Whether [error] means the device couldn't reach Supabase, so the mutation
/// should simply wait in the queue until the connection returns.
bool isRetryableMutationError(Object error) {
  return error is TimeoutException ||
      isIoNetworkError(error) ||
      error is ClientException ||
      error is AuthRetryableFetchException;
}

/// Whether the database rejected [error]'s mutation for its content, so
/// retrying it unchanged can never succeed. Anything else that isn't a
/// network error (a 5xx from the gateway, an expired session) is treated as
/// temporary.
bool isPermanentMutationError(Object error) {
  // Thrown by the direct-write fallback for an unknown mutation kind.
  if (error is ArgumentError) return true;
  if (error is! PostgrestException) return false;
  final code = error.code ?? '';
  // SQLSTATE class 22 is invalid data and 23 a broken constraint, such as a
  // referenced account or person that no longer exists. 42501 is a refusal
  // by row-level security, and P0002 means the row being changed is gone.
  return code.startsWith('22') ||
      code.startsWith('23') ||
      code == '42501' ||
      code == 'P0002';
}

/// A short explanation of why a queued change failed, for the user.
String describeMutationFailure(Object error, {required int attempts}) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '23503') {
      return 'An account, person or investment it uses was deleted.';
    }
    if (code == 'P0002') return 'What it changes no longer exists.';
    if (code.startsWith('22') || code.startsWith('23')) {
      return 'The server rejected some of its details.';
    }
    if (code == '42501') return "Your account isn't allowed to make it.";
  }
  if (error is ArgumentError) return 'This app version cannot save it.';
  return attempts > 1
      ? 'The server refused it $attempts times.'
      : 'The server refused it.';
}
