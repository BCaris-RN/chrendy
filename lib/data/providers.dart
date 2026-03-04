import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'draft_store.dart';
import 'phoenix_sync_worker.dart';
import 'retry_policy.dart';
import 'sync_queue_store.dart';

final draftStoreProvider = Provider<DraftStore>((ref) {
  return const SharedPreferencesDraftStore();
});

final retryHttpClientProvider = Provider<RetryHttpClient>((ref) {
  final client = RetryHttpClient(client: http.Client());
  ref.onDispose(client.close);
  return client;
});

final syncQueueStoreProvider = Provider<SyncQueueStore>((ref) {
  return SyncQueueStore(draftStore: ref.watch(draftStoreProvider));
});

final connectivityChangesProvider = Provider<Stream<bool>>((ref) {
  return watchConnectivityChanges();
});

final phoenixSyncWorkerProvider = Provider<PhoenixSyncWorker>((ref) {
  final worker = PhoenixSyncWorker(
    queueStore: ref.watch(syncQueueStoreProvider),
    retryHttpClient: ref.watch(retryHttpClientProvider),
    connectivityChanges: ref.watch(connectivityChangesProvider),
  );

  ref.onDispose(() {
    unawaited(worker.dispose());
  });

  return worker;
});

Stream<bool> watchConnectivityChanges({
  Duration interval = const Duration(seconds: 8),
}) async* {
  bool? previous;
  while (true) {
    final online = await _probeConnectivity();
    if (previous == null || previous != online) {
      previous = online;
      yield online;
    }
    await Future<void>.delayed(interval);
  }
}

Future<bool> _probeConnectivity() async {
  try {
    final addresses = await InternetAddress.lookup(
      'one.one.one.one',
    ).timeout(const Duration(seconds: 2));
    return addresses.isNotEmpty;
  } catch (_) {
    return false;
  }
}
