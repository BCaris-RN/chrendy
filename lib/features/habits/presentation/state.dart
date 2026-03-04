class HabitsState {
  const HabitsState({
    this.habitName = 'Daily Reflection',
    this.note = '',
    this.completed = false,
    this.pendingSyncCount = 0,
    this.isSyncing = false,
    this.statusMessage,
    this.errorMessage,
  });

  static const Object _unset = Object();

  final String habitName;
  final String note;
  final bool completed;
  final int pendingSyncCount;
  final bool isSyncing;
  final String? statusMessage;
  final String? errorMessage;

  HabitsState copyWith({
    String? habitName,
    String? note,
    bool? completed,
    int? pendingSyncCount,
    bool? isSyncing,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
  }) {
    return HabitsState(
      habitName: habitName ?? this.habitName,
      note: note ?? this.note,
      completed: completed ?? this.completed,
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
