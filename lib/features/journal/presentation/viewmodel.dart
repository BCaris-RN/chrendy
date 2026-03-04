import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/phoenix_sync_worker.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/data/sync_queue_store.dart';
import 'package:android_app_template/features/journal/domain/journal_entry.dart';

import 'state.dart';

final journalViewModelProvider =
    NotifierProvider<JournalViewModel, JournalState>(JournalViewModel.new);

class JournalViewModel extends Notifier<JournalState> {
  static const String _draftKey = 'journal_active_draft';

  DraftStore get _draftStore => ref.read(draftStoreProvider);
  SyncQueueStore get _queueStore => ref.read(syncQueueStoreProvider);
  PhoenixSyncWorker get _syncWorker => ref.read(phoenixSyncWorkerProvider);

  @override
  JournalState build() {
    return const JournalState();
  }

  Future<void> restoreLocalState() async {
    final draft = await _draftStore.restoreDraft(key: _draftKey);
    final text = draft?['text']?.toString() ?? '';
    final mood = _normalizeMood(draft?['moodScore']);
    final pending = await _queueStore.pendingCount();

    state = state.copyWith(
      draftText: text,
      moodScore: mood,
      pendingSyncCount: pending,
      statusMessage: text.isNotEmpty || pending > 0
          ? 'Recovered local draft and sync queue.'
          : state.statusMessage,
      errorMessage: null,
    );
  }

  Future<void> updateDraft(String value) async {
    try {
      await _persistDraft(text: value, moodScore: state.moodScore);
      state = state.copyWith(
        draftText: value,
        statusMessage: null,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        statusMessage: null,
        errorMessage: 'Local save failed. Draft is not lost but needs retry.',
      );
    }
  }

  Future<void> updateMoodScore(int value) async {
    final mood = _normalizeMood(value);
    try {
      await _persistDraft(text: state.draftText, moodScore: mood);
      state = state.copyWith(
        moodScore: mood,
        statusMessage: null,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        statusMessage: null,
        errorMessage: 'Local save failed. Mood update is queued locally.',
      );
    }
  }

  Future<void> submitEntry() async {
    if (state.isSyncing) {
      return;
    }

    final text = state.draftText.trim();
    if (text.isEmpty) {
      state = state.copyWith(
        statusMessage: null,
        errorMessage: 'Write something before syncing.',
      );
      return;
    }

    final mood = _normalizeMood(state.moodScore);
    final entry = JournalEntry.pendingSync(text: text, moodScore: mood);

    await _persistDraft(text: text, moodScore: mood);
    await _queueStore.enqueueJournalEntry(entry);
    final pendingAfterEnqueue = await _queueStore.pendingCount();

    state = state.copyWith(
      draftText: text,
      moodScore: mood,
      pendingSyncCount: pendingAfterEnqueue,
      isSyncing: true,
      statusMessage: 'Saved locally. Syncing through Phoenix worker...',
      errorMessage: null,
    );

    final result = await _syncWorker.flushPending();
    await _applySyncResult(result);
  }

  Future<void> retryPendingSync() async {
    if (state.isSyncing) {
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      statusMessage: 'Retrying pending queue...',
      errorMessage: null,
    );
    final result = await _syncWorker.flushPending();
    await _applySyncResult(result);
  }

  Future<void> clearLocalDraft() async {
    await _draftStore.clearDraft(key: _draftKey);
    final pending = await _queueStore.pendingCount();
    state = state.copyWith(
      draftText: '',
      moodScore: 3,
      pendingSyncCount: pending,
      isSyncing: false,
      statusMessage: 'Local draft cleared.',
      errorMessage: null,
    );
  }

  Future<void> _persistDraft({
    required String text,
    required int moodScore,
  }) async {
    await _draftStore.saveDraft(
      key: _draftKey,
      payload: <String, dynamic>{
        'text': text,
        'moodScore': _normalizeMood(moodScore),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _applySyncResult(SyncRunResult result) async {
    if (result.pendingCount == 0) {
      await _draftStore.clearDraft(key: _draftKey);
      state = state.copyWith(
        draftText: '',
        pendingSyncCount: 0,
        isSyncing: false,
        statusMessage: result.syncedCount > 0
            ? 'Synced successfully.'
            : 'Queue is already clear.',
        errorMessage: null,
      );
      return;
    }

    final fallbackError =
        'Network collapse detected. Draft retained locally for recovery.';
    final details = result.errorMessage == null
        ? ''
        : ' (${result.errorMessage})';
    state = state.copyWith(
      isSyncing: false,
      pendingSyncCount: result.pendingCount,
      statusMessage: null,
      errorMessage: '$fallbackError$details',
    );
  }

  int _normalizeMood(Object? raw) {
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (value == null) {
      return 3;
    }
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }
}
