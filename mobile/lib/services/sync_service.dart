import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/clouding_repository.dart';
import '../data/gateways.dart';

/// Two-way reconciliation between on-device history and the Pro cloud store.
///
/// - [syncAll]: uploads the full local history; the server merges by keeping
///   the larger count per day and returns the merged view, which is written
///   back locally. Run on upgrade to Pro and on app start for Pro users.
/// - [pushToday]: absolute write of today's count after each local change
///   (the device is the source of truth for the user's own taps, so resets
///   propagate too). Failures are swallowed; the next syncAll reconciles.
class SyncService extends ChangeNotifier {
  SyncService(this._gateway, this._localRepository);

  final CloudingSyncGateway _gateway;
  final CloudingRepository _localRepository;

  bool _syncing = false;
  DateTime? _lastSyncedAt;
  String? _lastPushKey;

  bool get isSyncing => _syncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Returns true when the sync completed. Local entries never shrink: the
  /// merge keeps the max of local and server per day.
  Future<bool> syncAll(String localUserId) async {
    if (_syncing) return false;
    _syncing = true;
    notifyListeners();
    try {
      final local = await _localRepository.getAllEntries(localUserId);
      final merged = await _gateway.syncHistory(local);
      for (final entry in merged.entries) {
        final localCount = local[entry.key] ?? 0;
        if (entry.value != localCount) {
          await _localRepository.setCountFor(
            localUserId,
            entry.key,
            entry.value,
          );
        }
      }
      _lastSyncedAt = DateTime.now();
      return true;
    } on ApiException {
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Fire-and-forget push of today's absolute count. Deduplicates repeat
  /// pushes of the same value (e.g. rebuild-triggered notifications).
  Future<void> pushToday(DateTime day, int count) async {
    final key = '${day.year}-${day.month}-${day.day}|$count';
    if (key == _lastPushKey) return;
    _lastPushKey = key;
    try {
      await _gateway.setToday(count);
    } on ApiException {
      // Offline or gated; forget the key so a later change retries.
      _lastPushKey = null;
    }
  }
}
