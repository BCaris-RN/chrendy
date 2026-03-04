class JournalState {
  const JournalState({
    this.draftText = '',
    this.moodScore = 3,
    this.pendingSyncCount = 0,
    this.isSyncing = false,
    this.statusMessage,
    this.errorMessage,
  });

  static const Object _unset = Object();

  final String draftText;
  final int moodScore;
  final int pendingSyncCount;
  final bool isSyncing;
  final String? statusMessage;
  final String? errorMessage;

  JournalState copyWith({
    String? draftText,
    int? moodScore,
    int? pendingSyncCount,
    bool? isSyncing,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
  }) {
    return JournalState(
      draftText: draftText ?? this.draftText,
      moodScore: moodScore ?? this.moodScore,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      isSyncing: isSyncing ?? this.isSyncing,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
