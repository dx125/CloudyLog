import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_config.dart';

abstract class ConfigRepository {
  Future<AppConfig> load();
  Future<void> save(AppConfig config);
}

class SharedPrefsConfigRepository implements ConfigRepository {
  SharedPrefsConfigRepository(this._prefs);

  static const String _keyRecommended = 'config_recommended_daily_count';
  static const String _keyLanguage = 'config_language_code';
  static const String _keyDisplayName = 'config_display_name';

  final SharedPreferences _prefs;

  @override
  Future<AppConfig> load() async {
    return AppConfig(
      recommendedDailyCount: _prefs.getInt(_keyRecommended) ??
          AppConfig.defaultRecommendedDailyCount,
      languageCode:
          _prefs.getString(_keyLanguage) ?? AppConfig.defaultLanguageCode,
      displayName:
          _prefs.getString(_keyDisplayName) ?? AppConfig.defaultDisplayName,
    );
  }

  @override
  Future<void> save(AppConfig config) async {
    await _prefs.setInt(_keyRecommended, config.recommendedDailyCount);
    await _prefs.setString(_keyLanguage, config.languageCode);
    await _prefs.setString(_keyDisplayName, config.displayName);
  }
}
