import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/phoenix_sync_worker.dart';
import 'package:android_app_template/data/retry_policy.dart';
import 'package:android_app_template/data/sync_queue_store.dart';
import 'package:android_app_template/features/journal/domain/journal_entry.dart';

class MemoryDraftStore implements DraftStore {
  final Map<String, Map<String, dynamic>> _storage =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    _storage[key] = Map<String, dynamic>.from(payload);
  }

  @override
  Future<Map<String, dynamic>?> restoreDraft({required String key}) async {
    final value = _storage[key];
    if (value == null) {
      return null;
    }
    return Map<String, dynamic>.from(value);
  }

  @override
  Future<void> clearDraft({required String key}) async {
    _storage.remove(key);
  }
}

RetryHttpClient _retryClientFor(http.Client client) {
  return RetryHttpClient(
    client: client,
    policy: const RetryPolicy(
      maxAttempts: 1,
      initialDelay: Duration.zero,
      maxDelay: Duration.zero,
      requestTimeout: Duration(milliseconds: 400),
      failureThreshold: 5,
      circuitOpenFor: Duration(seconds: 1),
    ),
  );
}

void main() {
  test(
    'worker flushes pending queue when connectivity becomes online',
    () async {
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      final draftStore = MemoryDraftStore();
      final queueStore = SyncQueueStore(draftStore: draftStore);
      await queueStore.enqueueJournalEntry(
        JournalEntry.pendingSync(text: 'queued entry', moodScore: 4),
      );

      final retryClient = _retryClientFor(
        MockClient((request) async => http.Response('ok', 201)),
      );
      final worker = PhoenixSyncWorker(
        queueStore: queueStore,
        retryHttpClient: retryClient,
        connectivityChanges: connectivity.stream,
      );
      addTearDown(worker.dispose);

      connectivity.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await queueStore.pendingCount(), 1);

      connectivity.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await queueStore.pendingCount(), 0);
    },
  );
}
