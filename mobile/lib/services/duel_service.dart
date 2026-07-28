import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/event_store.dart';
import '../data/gateways.dart';
import '../domain/duel.dart';
import '../domain/puff_event.dart';

/// Duels — the list, the join flow, score submission, and the live channel.
///
/// Scoring rule, which is the load-bearing part:
///   * async duels submit **tapped** events in the duel window
///   * live duels submit **heard** events
/// They are never added together. Mixing them would launder a classifier's
/// guess into the number that carries competitive weight.
class DuelService extends ChangeNotifier {
  DuelService(
    this._gateway,
    this._store, {
    DuelChannel? channel,
    DateTime Function()? clock,
    this.broadcastInterval = const Duration(seconds: 2),
  })  : _channel = channel,
        _clock = clock ?? DateTime.now;

  final DuelGateway _gateway;
  final EventStore _store;
  final DuelChannel? _channel;
  final DateTime Function() _clock;

  /// How often a live round publishes its count.
  ///
  /// Deliberately coarse. Realtime allows 500 msg/s project-wide on Pro, which
  /// at two clients per duel is only ~250 concurrent rounds at 1 msg/s each.
  /// Two seconds halves that pressure; the scoreboard still *feels* live
  /// because the local count renders optimistically between updates.
  final Duration broadcastInterval;

  List<Duel> _duels = const [];
  bool _loading = false;
  bool _limitReached = false;
  String? _activeDuelId;
  final Map<String, int> _liveOpponents = {};
  StreamSubscription<DuelLiveScore>? _liveSub;
  Timer? _broadcastTimer;
  int _liveCount = 0;

  List<Duel> get duels => _duels;
  bool get isLoading => _loading;

  /// True after a join was refused for want of Pro — the paywall cue.
  bool get limitReached => _limitReached;

  int get liveCount => _liveCount;
  Map<String, int> get liveOpponents => Map.unmodifiable(_liveOpponents);

  Duel? get activeDuel {
    final id = _activeDuelId;
    if (id == null) return null;
    for (final duel in _duels) {
      if (duel.id == id) return duel;
    }
    return null;
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _duels = await _gateway.list();
    } on CloudUnavailable {
      // Offline keeps the last list; duels are a cloud feature but must not
      // throw the user out of the tab.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Duel?> preview(String code) async {
    try {
      return await _gateway.preview(code.toUpperCase());
    } on CloudUnavailable {
      return null;
    }
  }

  /// Creates a duel. Pro-gated server-side; a free caller's 403 surfaces as
  /// [CloudUnavailable], which the UI turns into the paywall.
  Future<Duel?> create({required DuelKind kind}) async {
    try {
      final duel = await _gateway.create(kind: kind);
      _duels = [duel, ..._duels];
      notifyListeners();
      return duel;
    } on CloudUnavailable {
      return null;
    }
  }

  /// Returns true when the join landed. [limitReached] distinguishes "free
  /// tier is full" from "that code is no good" — different messages entirely.
  Future<bool> join(String code) async {
    _limitReached = false;
    try {
      await _gateway.join(code.toUpperCase());
      await refresh();
      return true;
    } on DuelLimitReached {
      _limitReached = true;
      notifyListeners();
      return false;
    } on DuelUnavailable {
      return false;
    } on CloudUnavailable {
      return false;
    }
  }

  Future<void> leave(String duelId) async {
    try {
      await _gateway.leave(duelId);
      _duels = [for (final d in _duels) if (d.id != duelId) d];
      notifyListeners();
    } on CloudUnavailable {
      // Nothing useful to do; the next refresh reconciles.
    }
  }

  /// Recomputes my score for [duel] from the local event log and submits it.
  ///
  /// The window is the duel's own, and the source depends on the kind — an
  /// async duel never counts heard events, and a live duel never counts taps.
  Future<void> submitScore(Duel duel) async {
    final now = _clock();
    // eventsBetween's upper bound is exclusive, so a plain `now` would drop an
    // event logged in the same instant as the submission — submit right after a
    // tap and it wouldn't count. Reach a tick past now, still clamped to the
    // duel's own end so a finished duel can never accrue later events.
    final until = duel.endsAt.isBefore(now)
        ? duel.endsAt
        : now.add(const Duration(milliseconds: 1));
    if (!until.isAfter(duel.startsAt)) return;

    final events = await _store.eventsBetween(
      duel.startsAt,
      until,
      source: duel.kind == DuelKind.live
          ? SourceFilter.heard
          : SourceFilter.tapped,
    );
    final count = events.where((e) => e.type == kTootType).length;

    try {
      await _gateway.submitScore(
        duel.id,
        tapped: duel.kind == DuelKind.live ? 0 : count,
        heard: duel.kind == DuelKind.live ? count : 0,
      );
    } on CloudUnavailable {
      // Offline: the score is derived from the local log, so the next
      // submission is correct anyway. Nothing is lost by skipping this one.
    }
  }

  /// Opens a live round: subscribes to the opponent's scores and starts
  /// publishing mine on [broadcastInterval].
  Future<void> startLive(Duel duel) async {
    final channel = _channel;
    if (channel == null) return;
    await stopLive();

    _activeDuelId = duel.id;
    _liveCount = 0;
    _liveOpponents.clear();

    _liveSub = channel.join(duel.id).listen((score) {
      _liveOpponents[score.userId] = score.count;
      notifyListeners();
    });

    _broadcastTimer = Timer.periodic(broadcastInterval, (_) {
      channel.publish(duel.id, _liveCount);
    });
    notifyListeners();
  }

  /// Called by the listening pipeline for each detection during a live round.
  /// Renders immediately; the network catches up on the next tick.
  void recordLiveDetection() {
    _liveCount++;
    notifyListeners();
  }

  Future<void> stopLive() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    await _liveSub?.cancel();
    _liveSub = null;
    await _channel?.leave();
    _activeDuelId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }
}
