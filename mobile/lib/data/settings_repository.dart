import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entitlement.dart';
import 'diagnostics_store.dart';

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

  /// 'YYYY-MM-DD' of the last successful world-stats report; null when the
  /// device has never reported.
  Future<String?> lastStatsReportDay();
  Future<void> setLastStatsReportDay(String day);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(
    this._prefs, {
    String Function()? newId,
    DiagnosticsRecorder? onError,
  })  : _newId = newId ?? _defaultNewId,
        _onError = onError;

  static const _keyDeviceId = 'device_id';
  static const _keyTheme = 'theme_mode';
  static const _keySound = 'sound_enabled';
  static const _keyCustomTags = 'custom_tags';
  static const _keyEntitlement = 'entitlement_cache';
  static const _keyLastStatsReport = 'last_stats_report_day';

  final SharedPreferences _prefs;
  final String Function() _newId;
  final DiagnosticsRecorder? _onError;

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
    } catch (e, stack) {
      _onError?.call('settings.entitlementCache', e, stack);
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

  @override
  Future<String?> lastStatsReportDay() async =>
      _prefs.getString(_keyLastStatsReport);

  @override
  Future<void> setLastStatsReportDay(String day) async {
    await _prefs.setString(_keyLastStatsReport, day);
  }
}
