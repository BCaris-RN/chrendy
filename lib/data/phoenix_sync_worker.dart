import 'dart:async';
import 'dart:convert';

import 'package:android_app_template/data/retry_policy.dart';
import 'package:android_app_template/data/sync_queue_store.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.pendingCount,
    required this.syncedCount,
    required this.failedCount,
    this.errorMessage,
  });

  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;
}

class PhoenixSyncWorker {
  PhoenixSyncWorker({
    required SyncQueueStore queueStore,
    required RetryHttpClient retryHttpClient,
    required Stream<bool> connectivityChanges,
  }) : _queueStore = queueStore,
       _retryHttpClient = retryHttpClient {
    _connectivitySubscription = connectivityChanges.distinct().listen((
      isOnline,
    ) {
      _isOnline = isOnline;
      if (isOnline) {
        unawaited(flushPending());
      }
    });
  }

  final SyncQueueStore _queueStore;
  final RetryHttpClient _retryHttpClient;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;
  String? _lastErrorMessage;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<SyncRunResult> flushPending() async {
    if (_isSyncing) {
      final pending = await _queueStore.pendingCount();
      return SyncRunResult(
        pendingCount: pending,
        syncedCount: 0,
        failedCount: 0,
        errorMessage: _lastErrorMessage,
      );
    }

    _isSyncing = true;
    _lastErrorMessage = null;
    var syncedCount = 0;
    var failedCount = 0;

    try {
      final pending = await _queueStore.readPending();
      for (final item in pending) {
        try {
          await _send(item);
          await _queueStore.removeItem(
            localId: item.localId,
            entityType: item.entityType,
          );
          syncedCount += 1;
        } catch (error) {
          _lastErrorMessage = error.toString();
          failedCount += 1;
          await _queueStore.markFailed(
            localId: item.localId,
            entityType: item.entityType,
          );
        }
      }

      final remaining = await _queueStore.pendingCount();
      return SyncRunResult(
        pendingCount: remaining,
        syncedCount: syncedCount,
        failedCount: failedCount,
        errorMessage: _lastErrorMessage,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _send(SyncQueueItem item) async {
    final uri = switch (item.entityType) {
      SyncEntityType.journalEntry => Uri.parse(
        'https://example.com/chrendy/journal',
      ),
      SyncEntityType.habitLog => Uri.parse(
        'https://example.com/chrendy/habits',
      ),
    };

    final response = await _retryHttpClient.execute((client) {
      return client.post(
        uri,
        headers: <String, String>{
          'content-type': 'application/json',
          'x-idempotency-key': item.localId,
        },
        body: jsonEncode(item.payload),
      );
    }, isIdempotent: true);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RetryExhaustedException(
        'Sync failed for ${item.entityType.wireValue}. '
        'Last status: ${response.statusCode}.',
      );
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }
}
