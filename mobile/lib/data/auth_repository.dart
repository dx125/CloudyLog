import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> loadUser();
  Future<void> saveUser(AuthUser user);
  Future<String?> loadToken();
  Future<void> saveToken(String token);
  Future<void> clear();
}

class SharedPrefsAuthRepository implements AuthRepository {
  SharedPrefsAuthRepository(this._prefs);

  static const String _keyUser = 'auth_current_user';
  static const String _keyToken = 'auth_token';

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
  Future<String?> loadToken() async {
    final raw = _prefs.getString(_keyToken);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  @override
  Future<void> saveToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_keyUser);
    await _prefs.remove(_keyToken);
  }
}
