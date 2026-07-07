import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/event_store.dart';
import '../domain/puff_event.dart';

/// The core loop. A tap appends one immutable event and bumps the in-memory
/// count optimistically — the DB write happens after the UI already reacted
/// (perceived latency is the product; haptics fire on the raw gesture, in the
/// widget, before this service is even called).
class TapService extends ChangeNotifier {
  TapService(
    this._store, {
    required String deviceId,
    DateTime Function()? clock,
    Uuid uuid = const Uuid(),
  })  : _deviceId = deviceId,
        _clock = clock ?? DateTime.now,
        _uuid = uuid;

  final EventStore _store;
  final String _deviceId;
  final DateTime Function() _clock;
  final Uuid _uuid;

  int _todayCount = 0;
  DateTime _today = DateTime(0);
  bool _loaded = false;

  String? _lastEventId;
  DateTime? _lastTapAt;
  List<String> _lastEventTags = const [];

  int get todayCount => _todayCount;
  bool get isLoaded => _loaded;
  DateTime get today => _today;

  /// True while quick tags may still be applied to the last log.
  bool get canTagLastEvent {
    final at = _lastTapAt;
    return _lastEventId != null &&
        at != null &&
        _clock().difference(at) < kQuickTagWindow;
  }

  /// Tags currently on the last log (drives chip selection in the window).
  List<String> get lastEventTags =>
      canTagLastEvent ? _lastEventTags : const [];

  Future<void> load() async {
    _today = dayOf(_clock());
    _todayCount = await _store.countForDay(_today);
    _loaded = true;
    notifyListeners();
  }

  /// Log one toot. Count first, persistence second — never the other way.
  Future<void> tap() async {
    _rollDayIfNeeded();
    final now = _clock();
    final event = PuffEvent(
      id: _uuid.v7(),
      occurredAt: now,
      deviceId: _deviceId,
    );
    _todayCount++;
    _lastEventId = event.id;
    _lastTapAt = now;
    _lastEventTags = const [];
    notifyListeners();
    await _store.insert(event);
  }

  /// Toggle a quick tag on the last log — only within [kQuickTagWindow].
  Future<void> toggleTagOnLastEvent(String tag) async {
    final id = _lastEventId;
    if (id == null || !canTagLastEvent) return;
    final tags = List<String>.from(_lastEventTags);
    if (!tags.remove(tag)) tags.add(tag);
    _lastEventTags = tags;
    notifyListeners();
    await _store.updateTags(id, tags);
  }

  /// Re-reads today's count if the calendar day rolled over while the app
  /// was suspended. Cheap to call on resume.
  Future<void> refreshIfStale() async {
    final day = dayOf(_clock());
    if (day == _today) return;
    _today = day;
    _todayCount = await _store.countForDay(day);
    notifyListeners();
  }

  void _rollDayIfNeeded() {
    final day = dayOf(_clock());
    if (day != _today) {
      _today = day;
      _todayCount = 0;
    }
  }
}
