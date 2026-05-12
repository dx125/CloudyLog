import 'package:flutter/foundation.dart';

import '../data/clouding_repository.dart';

class CloudingService extends ChangeNotifier {
  CloudingService(this._repository);

  final CloudingRepository _repository;

  String? _userId;
  int _todayCount = 0;
  DateTime _today = _startOfDay(DateTime.now());
  bool _loaded = false;

  String? get currentUserId => _userId;
  int get todayCount => _todayCount;
  bool get isLoaded => _loaded;

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Loads today's count for [userId]. Replaces any prior user's data in
  /// memory — call this whenever the authenticated user changes.
  Future<void> loadFor(String userId) async {
    _userId = userId;
    _today = _startOfDay(DateTime.now());
    _todayCount = await _repository.getCountFor(userId, _today);
    _loaded = true;
    notifyListeners();
  }

  /// Drops in-memory state. Call on sign-out so the next user doesn't see the
  /// previous user's count before [loadFor] completes.
  Future<void> clear() async {
    _userId = null;
    _today = _startOfDay(DateTime.now());
    _todayCount = 0;
    _loaded = false;
    notifyListeners();
  }

  Future<void> increment() async {
    final userId = _requireUserId();
    await _refreshIfNewDay(userId);
    _todayCount += 1;
    await _repository.setCountFor(userId, _today, _todayCount);
    notifyListeners();
  }

  Future<void> resetToday() async {
    final userId = _requireUserId();
    _today = _startOfDay(DateTime.now());
    _todayCount = 0;
    await _repository.setCountFor(userId, _today, 0);
    notifyListeners();
  }

  /// Re-reads today's count if the calendar day has rolled over since the
  /// last load. Cheap to call on app resume / screen open.
  Future<void> refreshIfStale() async {
    final userId = _userId;
    if (userId == null) return;
    final now = _startOfDay(DateTime.now());
    if (now == _today) return;
    _today = now;
    _todayCount = await _repository.getCountFor(userId, now);
    notifyListeners();
  }

  Future<Map<DateTime, int>> fetchHistory() {
    final userId = _requireUserId();
    return _repository.getAllEntries(userId);
  }

  Future<void> _refreshIfNewDay(String userId) async {
    final now = _startOfDay(DateTime.now());
    if (now != _today) {
      _today = now;
      _todayCount = await _repository.getCountFor(userId, now);
    }
  }

  String _requireUserId() {
    final id = _userId;
    if (id == null) {
      throw StateError('CloudingService used before loadFor(userId)');
    }
    return id;
  }
}
