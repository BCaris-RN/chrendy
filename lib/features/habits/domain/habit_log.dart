import 'package:android_app_template/core/ids/local_uuid.dart';
import 'package:android_app_template/core/sync/sync_status.dart';

class HabitLog {
  const HabitLog({
    required this.localId,
    required this.habitName,
    required this.note,
    required this.completed,
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String localId;
  final String habitName;
  final String note;
  final bool completed;
  final DateTime eventDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  factory HabitLog.pendingSync({
    required String habitName,
    required String note,
    required bool completed,
    DateTime? now,
    String? localId,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return HabitLog(
      localId: localId ?? generateLocalUuid(),
      habitName: habitName.trim(),
      note: note.trim(),
      completed: completed,
      eventDate: timestamp,
      createdAt: timestamp,
      updatedAt: timestamp,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  HabitLog copyWith({
    String? habitName,
    String? note,
    bool? completed,
    DateTime? eventDate,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return HabitLog(
      localId: localId,
      habitName: (habitName ?? this.habitName).trim(),
      note: (note ?? this.note).trim(),
      completed: completed ?? this.completed,
      eventDate: (eventDate ?? this.eventDate).toUtc(),
      createdAt: createdAt,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'localId': localId,
      'habitName': habitName,
      'note': note,
      'completed': completed,
      'eventDate': eventDate.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'syncStatus': syncStatus.wireValue,
    };
  }

  static HabitLog? fromMap(Map<String, dynamic> map) {
    final localId = map['localId']?.toString();
    final habitName = map['habitName']?.toString();
    final note = map['note']?.toString() ?? '';
    final completedRaw = map['completed'];
    final eventDate = DateTime.tryParse(map['eventDate']?.toString() ?? '');
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');

    if (localId == null ||
        localId.isEmpty ||
        habitName == null ||
        habitName.trim().isEmpty ||
        eventDate == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    final completed = completedRaw is bool
        ? completedRaw
        : completedRaw?.toString().toLowerCase() == 'true';

    return HabitLog(
      localId: localId,
      habitName: habitName.trim(),
      note: note,
      completed: completed,
      eventDate: eventDate.toUtc(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      syncStatus: syncStatusFromWire(map['syncStatus']),
    );
  }
}
