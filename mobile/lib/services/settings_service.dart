import 'package:flutter/material.dart';

import '../data/settings_repository.dart';

class SettingsService extends ChangeNotifier {
  SettingsService(this._repository);

  final SettingsRepository _repository;

  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = false;
  List<String> _customTags = const [];
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  List<String> get customTags => _customTags;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _themeMode = _parseMode(await _repository.themeMode());
    _soundEnabled = await _repository.soundEnabled();
    _customTags = await _repository.customTags();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _repository.setThemeMode(mode.name);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (value == _soundEnabled) return;
    _soundEnabled = value;
    await _repository.setSoundEnabled(value);
    notifyListeners();
  }

  /// Custom quick tags (Pro). Stable order, no duplicates, short and trimmed.
  Future<bool> addCustomTag(String raw) async {
    final tag = raw.trim();
    if (tag.isEmpty || tag.length > 16) return false;
    if (_customTags.contains(tag)) return false;
    _customTags = [..._customTags, tag];
    await _repository.setCustomTags(_customTags);
    notifyListeners();
    return true;
  }

  static ThemeMode _parseMode(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
