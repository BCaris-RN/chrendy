import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/phoenix_sync_worker.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/data/sync_queue_store.dart';
import 'package:android_app_template/features/habits/domain/habit_log.dart';

import 'state.dart';

final habitsViewModelProvider = NotifierProvider<HabitsViewModel, HabitsState>(
  HabitsViewModel.new,
);

class HabitsViewModel extends Notifier<HabitsState> {
  static const String _draftKey = 'habits_active_draft';

  DraftStore get _draftStore => ref.read(draftStoreProvider);
  SyncQueueStore get _queueStore => ref.read(syncQueueStoreProvider);
  PhoenixSyncWorker get _syncWorker => ref.read(phoenixSyncWorkerProvider);

  @override
  HabitsState build() {
    return const HabitsState();
  }

  Future<void> restoreLocalState() async {
    final draft = await _draftStore.restoreDraft(key: _draftKey);
    final pending = await _queueStore.pendingCount();

    state = state.copyWith(
      habitName: draft?['habitName']?.toString() ?? state.habitName,
      note: draft?['note']?.toString() ?? state.note,
      completed: _boolFromRaw(draft?['completed']),
      pendingSyncCount: pending,
      statusMessage: pending > 0 ? 'Recovered pending habit sync queue.' : null,
      errorMessage: null,
    );
  }

  Future<void> updateHabitName(String value) async {
    final next = value.trim().isEmpty ? state.habitName : value;
    await _persistDraft(
      habitName: next,
      note: state.note,
      completed: state.completed,
    );
    state = state.copyWith(
      habitName: next,
      statusMessage: null,
      errorMessage: null,
    );
  }

  Future<void> updateNote(String value) async {
    await _persistDraft(
      habitName: state.habitName,
      note: value,
      completed: state.completed,
    );
    state = state.copyWith(
      note: value,
      statusMessage: null,
      errorMessage: null,
    );
  }

  Future<void> updateCompleted(bool value) async {
    await _persistDraft(
      habitName: state.habitName,
      note: state.note,
      completed: value,
    );
    state = state.copyWith(
      completed: value,
      statusMessage: null,
      errorMessage: null,
    );
  }

  Future<void> submitHabitLog() async {
    if (state.isSyncing) {
      return;
    }

    final habitName = state.habitName.trim();
    if (habitName.isEmpty) {
      state = state.copyWith(
        statusMessage: null,
        errorMessage: 'Habit name is required before sync.',
      );
      return;
    }

    final log = HabitLog.pendingSync(
      habitName: habitName,
      note: state.note,
      completed: state.completed,
    );

    await _persistDraft(
      habitName: habitName,
      note: state.note,
      completed: state.completed,
    );
    await _queueStore.enqueueHabitLog(log);
    final pendingAfterEnqueue = await _queueStore.pendingCount();

    state = state.copyWith(
      pendingSyncCount: pendingAfterEnqueue,
      isSyncing: true,
      statusMessage: 'Habit log saved locally. Syncing now...',
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
      statusMessage: 'Retrying pending habit sync...',
      errorMessage: null,
    );

    final result = await _syncWorker.flushPending();
    await _applySyncResult(result);
  }

  Future<void> clearLocalDraft() async {
    await _draftStore.clearDraft(key: _draftKey);
    final pending = await _queueStore.pendingCount();
    state = state.copyWith(
      note: '',
      completed: false,
      pendingSyncCount: pending,
      statusMessage: 'Habit draft cleared.',
      errorMessage: null,
    );
  }

  Future<void> _persistDraft({
    required String habitName,
    required String note,
    required bool completed,
  }) async {
    await _draftStore.saveDraft(
      key: _draftKey,
      payload: <String, dynamic>{
        'habitName': habitName.trim(),
        'note': note,
        'completed': completed,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _applySyncResult(SyncRunResult result) async {
    if (result.pendingCount == 0) {
      await _draftStore.clearDraft(key: _draftKey);
      state = state.copyWith(
        note: '',
        completed: false,
        pendingSyncCount: 0,
        isSyncing: false,
        statusMessage: result.syncedCount > 0
            ? 'Habit log synced successfully.'
            : 'No pending items left.',
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(
      pendingSyncCount: result.pendingCount,
      isSyncing: false,
      statusMessage: null,
      errorMessage:
          'Network collapse detected. Habit log retained for retry.'
          '${result.errorMessage == null ? '' : ' (${result.errorMessage})'}',
    );
  }

  bool _boolFromRaw(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    return raw?.toString().toLowerCase() == 'true';
  }
}
