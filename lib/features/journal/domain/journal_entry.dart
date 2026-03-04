import 'package:android_app_template/core/ids/local_uuid.dart';
import 'package:android_app_template/core/sync/sync_status.dart';

class JournalEntry {
  const JournalEntry({
    required this.localId,
    required this.text,
    required this.moodScore,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String localId;
  final String text;
  final int moodScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  factory JournalEntry.pendingSync({
    required String text,
    required int moodScore,
    DateTime? now,
    String? localId,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return JournalEntry(
      localId: localId ?? generateLocalUuid(),
      text: text,
      moodScore: _normalizeMoodScore(moodScore),
      createdAt: timestamp,
      updatedAt: timestamp,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  JournalEntry copyWith({
    String? text,
    int? moodScore,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return JournalEntry(
      localId: localId,
      text: text ?? this.text,
      moodScore: _normalizeMoodScore(moodScore ?? this.moodScore),
      createdAt: createdAt,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'localId': localId,
      'text': text,
      'moodScore': moodScore,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'syncStatus': syncStatus.wireValue,
    };
  }

  static JournalEntry? fromMap(Map<String, dynamic> map) {
    final localId = map['localId']?.toString();
    final text = map['text']?.toString();
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
    final moodRaw = map['moodScore'];
    final mood = moodRaw is int
        ? moodRaw
        : int.tryParse(moodRaw?.toString() ?? '');

    if (localId == null ||
        localId.isEmpty ||
        text == null ||
        text.isEmpty ||
        createdAt == null ||
        updatedAt == null ||
        mood == null) {
      return null;
    }

    return JournalEntry(
      localId: localId,
      text: text,
      moodScore: _normalizeMoodScore(mood),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      syncStatus: syncStatusFromWire(map['syncStatus']),
    );
  }
}

int _normalizeMoodScore(int value) {
  if (value < 1) {
    return 1;
  }
  if (value > 5) {
    return 5;
  }
  return value;
}
