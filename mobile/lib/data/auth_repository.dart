import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> loadUser();
  Future<void> saveUser(AuthUser user);
  Future<void> clear();
}

class SharedPrefsAuthRepository implements AuthRepository {
  SharedPrefsAuthRepository(this._prefs);

  static const String _keyUser = 'auth_current_user';

  final SharedPreferences _prefs;

  @override
  Future<AuthUser?> loadUser() async {
    final raw = _prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.decode(raw);
    } catch (_) {
      await _prefs.remove(_keyUser);
      return null;
    }
  }

  @override
  Future<void> saveUser(AuthUser user) async {
    await _prefs.setString(_keyUser, user.encode());
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_keyUser);
  }
}
