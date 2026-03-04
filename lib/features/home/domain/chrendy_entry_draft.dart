enum EntrySyncState { pending, syncing, failed, synced }

class ChrendyEntryDraft {
  const ChrendyEntryDraft({
    required this.entryId,
    required this.moodScore,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    required this.retryCount,
  });

  final String entryId;
  final int moodScore;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntrySyncState syncState;
  final int retryCount;

  ChrendyEntryDraft copyWith({
    int? moodScore,
    String? text,
    DateTime? updatedAt,
    EntrySyncState? syncState,
    int? retryCount,
  }) {
    return ChrendyEntryDraft(
      entryId: entryId,
      moodScore: moodScore ?? this.moodScore,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'entryId': entryId,
      'moodScore': moodScore,
      'text': text,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'syncState': _syncStateToWire(syncState),
      'retryCount': retryCount,
    };
  }

  static ChrendyEntryDraft? fromMap(Map<String, dynamic> map) {
    final entryId = map['entryId']?.toString();
    final text = map['text']?.toString();
    final createdAtRaw = map['createdAt']?.toString();
    final updatedAtRaw = map['updatedAt']?.toString();

    if (entryId == null ||
        entryId.isEmpty ||
        text == null ||
        text.isEmpty ||
        createdAtRaw == null ||
        updatedAtRaw == null) {
      return null;
    }

    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    final updatedAt = DateTime.tryParse(updatedAtRaw)?.toUtc();
    if (createdAt == null || updatedAt == null) {
      return null;
    }

    final moodRaw = map['moodScore'];
    final retryRaw = map['retryCount'];
    final syncRaw = map['syncState']?.toString();

    final moodScore = _clampMoodScore(
      moodRaw is int ? moodRaw : int.tryParse(moodRaw?.toString() ?? ''),
    );

    final retryCount = retryRaw is int
        ? retryRaw
        : int.tryParse(retryRaw?.toString() ?? '') ?? 0;

    return ChrendyEntryDraft(
      entryId: entryId,
      moodScore: moodScore,
      text: text,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncState: _syncStateFromWire(syncRaw),
      retryCount: retryCount < 0 ? 0 : retryCount,
    );
  }

  static EntrySyncState _syncStateFromWire(String? value) {
    switch (value) {
      case 'syncing':
        return EntrySyncState.syncing;
      case 'failed':
        return EntrySyncState.failed;
      case 'synced':
        return EntrySyncState.synced;
      default:
        return EntrySyncState.pending;
    }
  }

  static String _syncStateToWire(EntrySyncState value) {
    switch (value) {
      case EntrySyncState.pending:
        return 'pending';
      case EntrySyncState.syncing:
        return 'syncing';
      case EntrySyncState.failed:
        return 'failed';
      case EntrySyncState.synced:
        return 'synced';
    }
  }

  static int _clampMoodScore(int? value) {
    final score = value ?? 3;
    if (score < 1) {
      return 1;
    }
    if (score > 5) {
      return 5;
    }
    return score;
  }
}
