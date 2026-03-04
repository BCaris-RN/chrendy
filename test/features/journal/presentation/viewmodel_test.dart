import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/data/retry_policy.dart';
import 'package:android_app_template/features/journal/presentation/viewmodel.dart';

class MemoryDraftStore implements DraftStore {
  MemoryDraftStore({this.onSave});

  final void Function()? onSave;
  final Map<String, Map<String, dynamic>> _storage =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    onSave?.call();
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
      requestTimeout: Duration(milliseconds: 300),
      failureThreshold: 5,
      circuitOpenFor: Duration(seconds: 1),
    ),
  );
}

ProviderContainer _createContainer({
  required DraftStore draftStore,
  required RetryHttpClient retryClient,
  Stream<bool>? connectivityStream,
}) {
  return ProviderContainer(
    overrides: <Override>[
      draftStoreProvider.overrideWithValue(draftStore),
      retryHttpClientProvider.overrideWithValue(retryClient),
      connectivityChangesProvider.overrideWithValue(
        connectivityStream ?? const Stream<bool>.empty(),
      ),
    ],
  );
}

void main() {
  test('journal draft is saved locally before state is mutated', () async {
    late ProviderContainer container;
    final observedDraftTexts = <String>[];
    final store = MemoryDraftStore(
      onSave: () {
        observedDraftTexts.add(
          container.read(journalViewModelProvider).draftText,
        );
      },
    );
    final retryClient = _retryClientFor(
      MockClient((request) async => http.Response('ok', 201)),
    );
    container = _createContainer(draftStore: store, retryClient: retryClient);
    addTearDown(container.dispose);

    final viewModel = container.read(journalViewModelProvider.notifier);
    await viewModel.updateDraft('Persist me first');

    expect(observedDraftTexts, isNotEmpty);
    expect(observedDraftTexts.first, equals(''));
    expect(
      container.read(journalViewModelProvider).draftText,
      'Persist me first',
    );
  });

  test(
    'network collapse keeps draft text and exposes recoverable error',
    () async {
      final store = MemoryDraftStore();
      final retryClient = _retryClientFor(
        MockClient((request) async {
          throw TimeoutException('upstream timeout');
        }),
      );
      final container = _createContainer(
        draftStore: store,
        retryClient: retryClient,
      );
      addTearDown(container.dispose);

      final viewModel = container.read(journalViewModelProvider.notifier);
      await viewModel.updateDraft('This must survive the outage');
      await viewModel.updateMoodScore(2);
      await viewModel.submitEntry();

      final state = container.read(journalViewModelProvider);
      final stored = await store.restoreDraft(key: 'journal_active_draft');

      expect(state.draftText, 'This must survive the outage');
      expect(state.pendingSyncCount, 1);
      expect(state.errorMessage, contains('Network collapse detected'));
      expect(stored, isNotNull);
      expect(stored!['text'], 'This must survive the outage');
    },
  );
}
