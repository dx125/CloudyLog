import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/config_repository.dart';
import '../data/models/app_config.dart';

class ConfigService extends ChangeNotifier {
  ConfigService(this._repository);

  final ConfigRepository _repository;

  AppConfig _config = AppConfig.defaults;
  bool _loaded = false;

  AppConfig get config => _config;
  int get recommendedDailyCount => _config.recommendedDailyCount;
  String get languageCode => _config.languageCode;
  String get displayName => _config.displayName;
  Locale get locale => Locale(_config.languageCode);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _config = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setRecommendedDailyCount(int value) async {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be greater than 0');
    }
    if (value == _config.recommendedDailyCount) return;
    _config = _config.copyWith(recommendedDailyCount: value);
    await _repository.save(_config);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    if (!AppConfig.supportedLanguageCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'unsupported language');
    }
    if (code == _config.languageCode) return;
    _config = _config.copyWith(languageCode: code);
    await _repository.save(_config);
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed == _config.displayName) return;
    _config = _config.copyWith(displayName: trimmed);
    await _repository.save(_config);
    notifyListeners();
  }
}
