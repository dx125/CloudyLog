import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/event_store.dart';
import '../data/gateways.dart';

/// The lightweight sync worker (handoff §7): batches unsynced events to the
/// cloud when online. Client-generated UUIDs make every push idempotent, so
/// retries are free. The local store is the source of truth — sync is a
/// mirror, never a dependency of the core loop.
class SyncService extends ChangeNotifier {
  SyncService(
    this._store,
    this._gateway, {
    required this.shouldSync,
    Duration debounce = const Duration(seconds: 15),
  }) : _debounce = debounce;

  static const int _batchSize = 500;

  final EventStore _store;
  final EventsSyncGateway _gateway;

  /// Sync is Pro-only and needs a session; the composition root supplies
  /// this check so the worker stays policy-free.
  final bool Function() shouldSync;

  final Duration _debounce;
  Timer? _pending;
  bool _syncing = false;
  DateTime? _lastSyncedAt;

  bool get isSyncing => _syncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Debounced push — called after every local change. The delay outlasts the
  /// quick-tag window so a tag edit rides along with its tap.
  void schedulePush() {
    if (!shouldSync()) return;
    _pending?.cancel();
    _pending = Timer(_debounce, () {
      pushPending();
    });
  }

  /// Pushes all unsynced events in batches. Returns true when everything
  /// pending went out.
  Future<bool> pushPending() async {
    if (_syncing || !shouldSync()) return false;
    _syncing = true;
    notifyListeners();
    try {
      while (true) {
        final batch = await _store.unsynced(_batchSize);
        if (batch.isEmpty) break;
        await _gateway.push(batch);
        await _store.markSynced(
          [for (final e in batch) e.id],
          DateTime.now(),
        );
      }
      _lastSyncedAt = DateTime.now();
      return true;
    } on CloudUnavailable {
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Restore-onto-a-new-device: pulls the full cloud log and merges it into
  /// the local store (same ids collapse; nothing local is lost).
  Future<bool> restoreFromCloud() async {
    if (_syncing) return false;
    _syncing = true;
    notifyListeners();
    try {
      final remote = await _gateway.pullAll();
      await _store.upsertAll(remote, synced: true);
      _lastSyncedAt = DateTime.now();
      return true;
    } on CloudUnavailable {
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }
}
