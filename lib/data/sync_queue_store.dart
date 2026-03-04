import 'package:android_app_template/core/sync/sync_status.dart';
import 'package:android_app_template/data/draft_store.dart';
import 'package:android_app_template/features/habits/domain/habit_log.dart';
import 'package:android_app_template/features/journal/domain/journal_entry.dart';

enum SyncEntityType { journalEntry, habitLog }

extension SyncEntityTypeCodec on SyncEntityType {
  String get wireValue {
    switch (this) {
      case SyncEntityType.journalEntry:
        return 'JOURNAL_ENTRY';
      case SyncEntityType.habitLog:
        return 'HABIT_LOG';
    }
  }
}

SyncEntityType _syncEntityTypeFromWire(Object? raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'HABIT_LOG':
      return SyncEntityType.habitLog;
    default:
      return SyncEntityType.journalEntry;
  }
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.localId,
    required this.entityType,
    required this.payload,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.retryCount,
  });

  final String localId;
  final SyncEntityType entityType;
  final Map<String, dynamic> payload;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int retryCount;

  SyncQueueItem copyWith({
    Map<String, dynamic>? payload,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      localId: localId,
      entityType: entityType,
      payload: payload ?? this.payload,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'localId': localId,
      'entityType': entityType.wireValue,
      'payload': payload,
      'syncStatus': syncStatus.wireValue,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'retryCount': retryCount,
    };
  }

  static SyncQueueItem? fromMap(Map<String, dynamic> map) {
    final localId = map['localId']?.toString();
    final payload = map['payload'];
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
    final retryRaw = map['retryCount'];
    final retryCount = retryRaw is int
        ? retryRaw
        : int.tryParse(retryRaw?.toString() ?? '');

    if (localId == null ||
        localId.isEmpty ||
        payload is! Map<String, dynamic> ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return SyncQueueItem(
      localId: localId,
      entityType: _syncEntityTypeFromWire(map['entityType']),
      payload: payload,
      syncStatus: syncStatusFromWire(map['syncStatus']),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      retryCount: (retryCount ?? 0) < 0 ? 0 : (retryCount ?? 0),
    );
  }
}

class SyncQueueStore {
  SyncQueueStore({
    required DraftStore draftStore,
    this.queueKey = 'chrendy_sync_queue',
  }) : _draftStore = draftStore;

  final DraftStore _draftStore;
  final String queueKey;

  Future<void> enqueueJournalEntry(JournalEntry entry) async {
    final item = SyncQueueItem(
      localId: entry.localId,
      entityType: SyncEntityType.journalEntry,
      payload: entry.toMap(),
      syncStatus: entry.syncStatus,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      retryCount: 0,
    );
    await upsert(item);
  }

  Future<void> enqueueHabitLog(HabitLog log) async {
    final item = SyncQueueItem(
      localId: log.localId,
      entityType: SyncEntityType.habitLog,
      payload: log.toMap(),
      syncStatus: log.syncStatus,
      createdAt: log.createdAt,
      updatedAt: log.updatedAt,
      retryCount: 0,
    );
    await upsert(item);
  }

  Future<void> upsert(SyncQueueItem item) async {
    final all = await readAll();
    final next = <SyncQueueItem>[
      ...all.where((candidate) {
        return !(candidate.localId == item.localId &&
            candidate.entityType == item.entityType);
      }),
      item,
    ];
    await _save(next);
  }

  Future<List<SyncQueueItem>> readAll() async {
    final payload = await _draftStore.restoreDraft(key: queueKey);
    final entries = payload?['entries'];
    if (entries is! List) {
      return <SyncQueueItem>[];
    }

    final parsed = <SyncQueueItem>[];
    for (final raw in entries) {
      if (raw is Map<String, dynamic>) {
        final item = SyncQueueItem.fromMap(raw);
        if (item != null) {
          parsed.add(item);
        }
        continue;
      }

      if (raw is Map) {
        final item = SyncQueueItem.fromMap(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (item != null) {
          parsed.add(item);
        }
      }
    }
    return parsed;
  }

  Future<List<SyncQueueItem>> readPending() async {
    final all = await readAll();
    return all
        .where((item) {
          return item.syncStatus == SyncStatus.pendingSync ||
              item.syncStatus == SyncStatus.failed;
        })
        .toList(growable: false);
  }

  Future<int> pendingCount() async {
    final pending = await readPending();
    return pending.length;
  }

  Future<void> removeItem({
    required String localId,
    required SyncEntityType entityType,
  }) async {
    final all = await readAll();
    final next = all
        .where((item) {
          return !(item.localId == localId && item.entityType == entityType);
        })
        .toList(growable: false);
    await _save(next);
  }

  Future<void> markFailed({
    required String localId,
    required SyncEntityType entityType,
  }) async {
    final all = await readAll();
    final now = DateTime.now().toUtc();
    final next = all
        .map((item) {
          if (item.localId != localId || item.entityType != entityType) {
            return item;
          }
          return item.copyWith(
            syncStatus: SyncStatus.failed,
            updatedAt: now,
            retryCount: item.retryCount + 1,
          );
        })
        .toList(growable: false);
    await _save(next);
  }

  Future<void> _save(List<SyncQueueItem> items) async {
    if (items.isEmpty) {
      await _draftStore.clearDraft(key: queueKey);
      return;
    }

    await _draftStore.saveDraft(
      key: queueKey,
      payload: <String, dynamic>{
        'entries': items.map((item) => item.toMap()).toList(growable: false),
      },
    );
  }
}
