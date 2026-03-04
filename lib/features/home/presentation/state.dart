class HomeState {
  const HomeState({
    this.draftText = '',
    this.moodScore = 3,
    this.outboxCount = 0,
    this.isSubmitting = false,
    this.statusMessage,
    this.errorMessage,
  });

  static const Object _unset = Object();

  final String draftText;
  final int moodScore;
  final int outboxCount;
  final bool isSubmitting;
  final String? statusMessage;
  final String? errorMessage;

  HomeState copyWith({
    String? draftText,
    int? moodScore,
    int? outboxCount,
    bool? isSubmitting,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
  }) {
    return HomeState(
      draftText: draftText ?? this.draftText,
      moodScore: moodScore ?? this.moodScore,
      outboxCount: outboxCount ?? this.outboxCount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
