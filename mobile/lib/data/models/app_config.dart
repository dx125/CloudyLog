class AppConfig {
  const AppConfig({
    required this.recommendedDailyCount,
    required this.languageCode,
    required this.displayName,
  });

  static const int defaultRecommendedDailyCount = 35;
  static const String defaultLanguageCode = 'en';
  static const String defaultDisplayName = '';

  static const List<String> supportedLanguageCodes = ['en', 'es'];

  static const AppConfig defaults = AppConfig(
    recommendedDailyCount: defaultRecommendedDailyCount,
    languageCode: defaultLanguageCode,
    displayName: defaultDisplayName,
  );

  final int recommendedDailyCount;
  final String languageCode;
  final String displayName;

  AppConfig copyWith({
    int? recommendedDailyCount,
    String? languageCode,
    String? displayName,
  }) =>
      AppConfig(
        recommendedDailyCount:
            recommendedDailyCount ?? this.recommendedDailyCount,
        languageCode: languageCode ?? this.languageCode,
        displayName: displayName ?? this.displayName,
      );
}
