import 'package:shared_preferences/shared_preferences.dart';

import 'models/subscription_status.dart';

/// Local cache of the last server-reported subscription so Pro features stay
/// available offline until the entitlement expires.
abstract class SubscriptionRepository {
  Future<SubscriptionStatus?> load();
  Future<void> save(SubscriptionStatus status);
  Future<void> clear();
}

class SharedPrefsSubscriptionRepository implements SubscriptionRepository {
  SharedPrefsSubscriptionRepository(this._prefs);

  static const String _keyStatus = 'subscription_status';

  final SharedPreferences _prefs;

  @override
  Future<SubscriptionStatus?> load() async {
    final raw = _prefs.getString(_keyStatus);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SubscriptionStatus.decode(raw);
    } catch (_) {
      await _prefs.remove(_keyStatus);
      return null;
    }
  }

  @override
  Future<void> save(SubscriptionStatus status) async {
    await _prefs.setString(_keyStatus, status.encode());
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_keyStatus);
  }
}
