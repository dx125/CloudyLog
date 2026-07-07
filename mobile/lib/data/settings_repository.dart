import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entitlement.dart';

/// Small device-local settings + caches. Event data never lives here — that's
/// the Drift store's job.
abstract class SettingsRepository {
  Future<String> deviceId();
  Future<String> themeMode(); // 'system' | 'light' | 'dark'
  Future<void> setThemeMode(String mode);
  Future<bool> soundEnabled();
  Future<void> setSoundEnabled(bool value);
  Future<List<String>> customTags();
  Future<void> setCustomTags(List<String> tags);
  Future<Entitlement?> cachedEntitlement();
  Future<void> cacheEntitlement(Entitlement? entitlement);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs, {String Function()? newId})
      : _newId = newId ?? _defaultNewId;

  static const _keyDeviceId = 'device_id';
  static const _keyTheme = 'theme_mode';
  static const _keySound = 'sound_enabled';
  static const _keyCustomTags = 'custom_tags';
  static const _keyEntitlement = 'entitlement_cache';

  final SharedPreferences _prefs;
  final String Function() _newId;

  static String _defaultNewId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  Future<String> deviceId() async {
    final existing = _prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _newId();
    await _prefs.setString(_keyDeviceId, id);
    return id;
  }

  @override
  Future<String> themeMode() async => _prefs.getString(_keyTheme) ?? 'system';

  @override
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyTheme, mode);
  }

  @override
  Future<bool> soundEnabled() async => _prefs.getBool(_keySound) ?? false;

  @override
  Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool(_keySound, value);
  }

  @override
  Future<List<String>> customTags() async =>
      _prefs.getStringList(_keyCustomTags) ?? const [];

  @override
  Future<void> setCustomTags(List<String> tags) async {
    await _prefs.setStringList(_keyCustomTags, tags);
  }

  @override
  Future<Entitlement?> cachedEntitlement() async {
    final raw = _prefs.getString(_keyEntitlement);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Entitlement.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      await _prefs.remove(_keyEntitlement);
      return null;
    }
  }

  @override
  Future<void> cacheEntitlement(Entitlement? entitlement) async {
    if (entitlement == null) {
      await _prefs.remove(_keyEntitlement);
    } else {
      await _prefs.setString(_keyEntitlement, jsonEncode(entitlement.toJson()));
    }
  }
}
