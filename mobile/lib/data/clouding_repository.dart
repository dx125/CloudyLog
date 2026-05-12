import 'package:shared_preferences/shared_preferences.dart';

import 'models/clouding_entry.dart';

abstract class CloudingRepository {
  Future<int> getCountFor(String userId, DateTime date);
  Future<void> setCountFor(String userId, DateTime date, int count);
  Future<Map<DateTime, int>> getAllEntries(String userId);
}

class SharedPrefsCloudingRepository implements CloudingRepository {
  SharedPrefsCloudingRepository(this._prefs);

  // Keys are namespaced by userId so two accounts on the same device don't
  // share counts. Old (pre-multi-user) keys without a userId segment are
  // ignored on read.
  static const String _prefix = 'clouding_count_';

  final SharedPreferences _prefs;

  @override
  Future<int> getCountFor(String userId, DateTime date) async {
    return _prefs.getInt(_keyFor(userId, CloudingEntry.dateKey(date))) ?? 0;
  }

  @override
  Future<void> setCountFor(String userId, DateTime date, int count) async {
    await _prefs.setInt(_keyFor(userId, CloudingEntry.dateKey(date)), count);
  }

  @override
  Future<Map<DateTime, int>> getAllEntries(String userId) async {
    final scopedPrefix = '$_prefix${userId}_';
    final entries = <DateTime, int>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(scopedPrefix)) continue;
      final date = _tryParseDate(key.substring(scopedPrefix.length));
      if (date == null) continue;
      final value = _prefs.getInt(key);
      if (value == null) continue;
      entries[date] = value;
    }
    return entries;
  }

  static String _keyFor(String userId, String yyyyMMdd) =>
      '$_prefix${userId}_$yyyyMMdd';

  static DateTime? _tryParseDate(String yyyyMMdd) {
    final parts = yyyyMMdd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
