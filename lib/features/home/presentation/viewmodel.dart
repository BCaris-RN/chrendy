import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/data/retry_policy.dart';
import 'package:android_app_template/features/home/domain/chrendy_entry_draft.dart';

import 'state.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

class HomeViewModel extends Notifier<HomeState> {
  static const String _activeDraftKey = 'chrendy_active_draft';
  static const String _outboxKey = 'chrendy_outbox';
  static final RegExp _statusCodePattern = RegExp(
    r'\bstatus:\s*(\d{3})\b',
    caseSensitive: false,
  );

  DraftStore get _draftStore => ref.read(draftStoreProvider);
  RetryHttpClient get _retryClient => ref.read(retryHttpClientProvider);

  @override
  HomeState build() {
    return const HomeState();
  }

  Future<void> restoreDraft() async {
    final draft = await _draftStore.restoreDraft(key: _activeDraftKey);
    final restoredText = draft?['text']?.toString() ?? '';
    final restoredMood = _coerceMoodScore(draft?['moodScore']);
    final outbox = await _loadOutbox();

    state = state.copyWith(
      draftText: restoredText,
      moodScore: restoredMood,
      outboxCount: outbox.length,
      statusMessage: restoredText.isNotEmpty || outbox.isNotEmpty
          ? 'Recovered local journal state after restart.'
          : state.statusMessage,
      errorMessage: null,
    );
  }

  void updateDraft(String value) {
    state = state.copyWith(
      draftText: value,
      statusMessage: null,
      errorMessage: null,
    );
    unawaited(
      _persistActiveDraft(draftText: value, moodScore: state.moodScore),
    );
  }

  void updateMoodScore(int value) {
    final normalizedMood = _coerceMoodScore(value);
    state = state.copyWith(
      moodScore: normalizedMood,
      statusMessage: null,
      errorMessage: null,
    );
    unawaited(
      _persistActiveDraft(
        draftText: state.draftText,
        moodScore: normalizedMood,
      ),
    );
  }

  Future<void> submitDraft() async {
    if (state.isSubmitting) {
      return;
    }

    final text = state.draftText.trim();
    if (text.isEmpty) {
      state = state.copyWith(
        statusMessage: null,
        errorMessage: 'Error: add content before submit.',
      );
      return;
    }

    final moodScore = _coerceMoodScore(state.moodScore);
    final createdAt = DateTime.now().toUtc();
    final entry = ChrendyEntryDraft(
      entryId: _buildEntryId(createdAt, text),
      moodScore: moodScore,
      text: text,
      createdAt: createdAt,
      updatedAt: createdAt,
      syncState: EntrySyncState.pending,
      retryCount: 0,
    );

    await _persistActiveDraft(draftText: text, moodScore: moodScore);
    final outboxCount = await _enqueueOutboxEntry(entry);

    state = state.copyWith(
      draftText: text,
      moodScore: moodScore,
      outboxCount: outboxCount,
      isSubmitting: true,
      statusMessage: 'Saved locally. Syncing now...',
      errorMessage: null,
    );

    await _syncEntry(entry, clearActiveDraftOnSuccess: true);
  }

  Future<void> retryPendingSync() async {
    if (state.isSubmitting) {
      return;
    }

    final outbox = await _loadOutbox();
    if (outbox.isEmpty) {
      state = state.copyWith(
        statusMessage: 'No pending entries to retry.',
        errorMessage: null,
      );
      return;
    }

    final next = outbox.first;
    state = state.copyWith(
      isSubmitting: true,
      outboxCount: outbox.length,
      statusMessage: 'Retrying pending sync...',
      errorMessage: null,
    );

    await _syncEntry(next, clearActiveDraftOnSuccess: false);
  }

  Future<void> clearLocalDraft() async {
    await _draftStore.clearDraft(key: _activeDraftKey);
    state = state.copyWith(
      draftText: '',
      moodScore: 3,
      isSubmitting: false,
      statusMessage: 'Local draft cleared.',
      errorMessage: null,
    );
  }

  Future<void> _syncEntry(
    ChrendyEntryDraft entry, {
    required bool clearActiveDraftOnSuccess,
  }) async {
    final payload = <String, dynamic>{
      'entryId': entry.entryId,
      'moodScore': entry.moodScore,
      'text': entry.text,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _retryClient.execute(
        (client) => client.post(
          Uri.parse('https://example.com/chrendy/entries'),
          headers: <String, String>{
            'content-type': 'application/json',
            'x-idempotency-key': entry.entryId,
          },
          body: jsonEncode(payload),
        ),
        isIdempotent: true,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final outbox = await _removeOutboxEntry(entry.entryId);
        if (clearActiveDraftOnSuccess) {
          await _draftStore.clearDraft(key: _activeDraftKey);
        }
        state = state.copyWith(
          isSubmitting: false,
          outboxCount: outbox.length,
          statusMessage: 'Sync complete. Local draft is safe.',
          errorMessage: null,
        );
        return;
      }

      final outboxCount = await _markOutboxEntryFailed(entry.entryId);
      state = state.copyWith(
        isSubmitting: false,
        outboxCount: outboxCount,
        statusMessage: null,
        errorMessage:
            'Error: upstream returned ${response.statusCode}. Draft retained for retry.',
      );
    } on CircuitBreakerOpenException catch (error) {
      final outboxCount = await _markOutboxEntryFailed(entry.entryId);
      state = state.copyWith(
        isSubmitting: false,
        outboxCount: outboxCount,
        statusMessage: null,
        errorMessage:
            'Error: service unavailable. Retry in ${error.retryAfter.inSeconds}s. Draft retained.',
      );
    } on RetryExhaustedException catch (error) {
      final outboxCount = await _markOutboxEntryFailed(entry.entryId);
      final statusCode = _extractStatusCode(error.message);
      final statusFragment = statusCode == null ? '' : ' ($statusCode)';
      state = state.copyWith(
        isSubmitting: false,
        outboxCount: outboxCount,
        statusMessage: null,
        errorMessage:
            'Error: sync failed$statusFragment. Draft retained for retry.',
      );
    } catch (_) {
      final outboxCount = await _markOutboxEntryFailed(entry.entryId);
      state = state.copyWith(
        isSubmitting: false,
        outboxCount: outboxCount,
        statusMessage: null,
        errorMessage: 'Error: network failure. Draft retained for retry.',
      );
    }
  }

  Future<void> _persistActiveDraft({
    required String draftText,
    required int moodScore,
  }) async {
    final payload = <String, dynamic>{
      'text': draftText,
      'moodScore': _coerceMoodScore(moodScore),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _draftStore.saveDraft(key: _activeDraftKey, payload: payload);
  }

  Future<List<ChrendyEntryDraft>> _loadOutbox() async {
    final outboxPayload = await _draftStore.restoreDraft(key: _outboxKey);
    final rawEntries = outboxPayload?['entries'];
    if (rawEntries is! List) {
      return <ChrendyEntryDraft>[];
    }

    final parsed = <ChrendyEntryDraft>[];
    for (final raw in rawEntries) {
      if (raw is Map<String, dynamic>) {
        final entry = ChrendyEntryDraft.fromMap(raw);
        if (entry != null) {
          parsed.add(entry);
        }
        continue;
      }

      if (raw is Map) {
        final mapped = raw.map((key, value) => MapEntry(key.toString(), value));
        final entry = ChrendyEntryDraft.fromMap(mapped);
        if (entry != null) {
          parsed.add(entry);
        }
      }
    }

    return parsed;
  }

  Future<void> _saveOutbox(List<ChrendyEntryDraft> entries) async {
    if (entries.isEmpty) {
      await _draftStore.clearDraft(key: _outboxKey);
      return;
    }

    await _draftStore.saveDraft(
      key: _outboxKey,
      payload: <String, dynamic>{
        'entries': entries
            .map((entry) => entry.toMap())
            .toList(growable: false),
      },
    );
  }

  Future<int> _enqueueOutboxEntry(ChrendyEntryDraft entry) async {
    final outbox = await _loadOutbox();
    final next = <ChrendyEntryDraft>[
      ...outbox.where((candidate) => candidate.entryId != entry.entryId),
      entry,
    ];
    await _saveOutbox(next);
    return next.length;
  }

  Future<List<ChrendyEntryDraft>> _removeOutboxEntry(String entryId) async {
    final outbox = await _loadOutbox();
    final remaining = outbox
        .where((entry) => entry.entryId != entryId)
        .toList(growable: false);
    if (remaining.length != outbox.length) {
      await _saveOutbox(remaining);
    }
    return remaining;
  }

  Future<int> _markOutboxEntryFailed(String entryId) async {
    final outbox = await _loadOutbox();
    if (outbox.isEmpty) {
      return 0;
    }

    final now = DateTime.now().toUtc();
    final next = outbox
        .map((entry) {
          if (entry.entryId != entryId) {
            return entry;
          }

          return entry.copyWith(
            syncState: EntrySyncState.failed,
            retryCount: entry.retryCount + 1,
            updatedAt: now,
          );
        })
        .toList(growable: false);

    await _saveOutbox(next);
    return next.length;
  }

  int _coerceMoodScore(Object? rawValue) {
    final value = rawValue is int
        ? rawValue
        : int.tryParse(rawValue?.toString() ?? '');
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

  String _buildEntryId(DateTime timestamp, String text) {
    final hash = text.hashCode.abs().toRadixString(16);
    return 'entry-${timestamp.microsecondsSinceEpoch}-$hash';
  }

  int? _extractStatusCode(String message) {
    final match = _statusCodePattern.firstMatch(message);
    if (match == null) {
      return null;
    }

    final raw = match.group(1);
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw);
  }
}
