enum SyncStatus { draft, pendingSync, synced, failed }

extension SyncStatusCodec on SyncStatus {
  String get wireValue {
    switch (this) {
      case SyncStatus.draft:
        return 'DRAFT';
      case SyncStatus.pendingSync:
        return 'PENDING_SYNC';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.failed:
        return 'FAILED';
    }
  }
}

SyncStatus syncStatusFromWire(Object? raw) {
  final value = raw?.toString().toUpperCase();
  switch (value) {
    case 'DRAFT':
      return SyncStatus.draft;
    case 'PENDING_SYNC':
      return SyncStatus.pendingSync;
    case 'SYNCED':
      return SyncStatus.synced;
    case 'FAILED':
      return SyncStatus.failed;
    default:
      return SyncStatus.draft;
  }
}
