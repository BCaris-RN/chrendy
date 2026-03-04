import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/data/retry_policy.dart';
import 'package:android_app_template/features/home/presentation/viewmodel.dart';

class MemoryDraftStore implements DraftStore {
  MemoryDraftStore({this.onSave});

  final void Function()? onSave;
  final Map<String, Map<String, dynamic>> _storage =
      <String, Map<String, dynamic>>{};
  int saveCalls = 0;
  int clearCalls = 0;

  void seed(String key, Map<String, dynamic> payload) {
    _storage[key] = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    saveCalls += 1;
    onSave?.call();
    _storage[key] = Map<String, dynamic>.from(payload);
  }

  @override
  Future<Map<String, dynamic>?> restoreDraft({required String key}) async {
    final draft = _storage[key];
    if (draft == null) {
      return null;
    }
    return Map<String, dynamic>.from(draft);
  }

  @override
  Future<void> clearDraft({required String key}) async {
    clearCalls += 1;
    _storage.remove(key);
  }
}

ProviderContainer _createContainer({
  required MemoryDraftStore draftStore,
  required RetryHttpClient retryClient,
}) {
  return ProviderContainer(
    overrides: <Override>[
      draftStoreProvider.overrideWithValue(draftStore),
      retryHttpClientProvider.overrideWithValue(retryClient),
    ],
  );
}

RetryHttpClient _retryClientFor(http.Client client) {
  return RetryHttpClient(
    client: client,
    policy: const RetryPolicy(
      maxAttempts: 1,
      initialDelay: Duration.zero,
      maxDelay: Duration.zero,
      requestTimeout: Duration(seconds: 1),
      failureThreshold: 5,
      circuitOpenFor: Duration(seconds: 1),
    ),
  );
}

void main() {
  test('submitDraft saves locally before network mutation', () async {
    final events = <String>[];
    final store = MemoryDraftStore(onSave: () => events.add('save'));
    final client = _retryClientFor(
      MockClient((request) async {
        events.add('network');
        return http.Response('{"ok":true}', 201);
      }),
    );
    final container = _createContainer(draftStore: store, retryClient: client);
    addTearDown(container.dispose);

    final viewModel = container.read(homeViewModelProvider.notifier);
    viewModel.updateDraft('Offline-safe journaling entry');
    viewModel.updateMoodScore(4);

    await viewModel.submitDraft();

    expect(events, containsAllInOrder(<String>['save', 'network']));
    expect(store.clearCalls, greaterThanOrEqualTo(1));
    expect(container.read(homeViewModelProvider).outboxCount, 0);
  });

  test('submitDraft keeps local recoverable state on timeout', () async {
    final store = MemoryDraftStore();
    final client = _retryClientFor(
      MockClient((request) async => throw TimeoutException('timed out')),
    );
    final container = _createContainer(draftStore: store, retryClient: client);
    addTearDown(container.dispose);

    final viewModel = container.read(homeViewModelProvider.notifier);
    viewModel.updateDraft('Entry that must survive outage');
    viewModel.updateMoodScore(2);

    await viewModel.submitDraft();

    final restored = await store.restoreDraft(key: 'chrendy_active_draft');
    final state = container.read(homeViewModelProvider);
    expect(restored, isNotNull);
    expect(restored!['text'], 'Entry that must survive outage');
    expect(state.outboxCount, 1);
    expect(state.errorMessage, contains('Draft retained'));
  });

  test('submitDraft retains entry when upstream returns 500', () async {
    final store = MemoryDraftStore();
    final client = _retryClientFor(
      MockClient((request) async => http.Response('server error', 500)),
    );
    final container = _createContainer(draftStore: store, retryClient: client);
    addTearDown(container.dispose);

    final viewModel = container.read(homeViewModelProvider.notifier);
    viewModel.updateDraft('Unsynced entry');
    viewModel.updateMoodScore(3);

    await viewModel.submitDraft();

    final state = container.read(homeViewModelProvider);
    expect(state.outboxCount, 1);
    expect(state.errorMessage, contains('500'));
  });

  test('restoreDraft hydrates active draft and pending outbox', () async {
    final store = MemoryDraftStore()
      ..seed('chrendy_active_draft', <String, dynamic>{
        'text': 'Recovered from local storage',
        'moodScore': 5,
      })
      ..seed('chrendy_outbox', <String, dynamic>{
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'entryId': 'entry-1',
            'moodScore': 5,
            'text': 'Recovered from local storage',
            'createdAt': '2026-03-03T00:00:00.000Z',
            'updatedAt': '2026-03-03T00:00:00.000Z',
            'syncState': 'failed',
            'retryCount': 1,
          },
        ],
      });

    final client = _retryClientFor(
      MockClient((request) async => throw TimeoutException('offline')),
    );
    final container = _createContainer(draftStore: store, retryClient: client);
    addTearDown(container.dispose);

    final viewModel = container.read(homeViewModelProvider.notifier);
    await viewModel.restoreDraft();
    final state = container.read(homeViewModelProvider);

    expect(state.draftText, 'Recovered from local storage');
    expect(state.moodScore, 5);
    expect(state.outboxCount, 1);
    expect(state.statusMessage, contains('Recovered'));
  });
}
