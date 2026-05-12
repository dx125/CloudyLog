import 'package:cloudy_log/data/config_repository.dart';
import 'package:cloudy_log/data/models/app_config.dart';
import 'package:cloudy_log/services/config_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryConfigRepository implements ConfigRepository {
  AppConfig _config = AppConfig.defaults;

  @override
  Future<AppConfig> load() async => _config;

  @override
  Future<void> save(AppConfig config) async {
    _config = config;
  }
}

void main() {
  group('ConfigService', () {
    test('defaults to 35 when nothing stored', () async {
      final service = ConfigService(_InMemoryConfigRepository());
      await service.load();
      expect(service.recommendedDailyCount, 35);
    });

    test('persists updates', () async {
      final repo = _InMemoryConfigRepository();
      final service = ConfigService(repo);
      await service.load();
      await service.setRecommendedDailyCount(50);
      expect(service.recommendedDailyCount, 50);
      expect((await repo.load()).recommendedDailyCount, 50);
    });

    test('rejects non-positive values', () async {
      final service = ConfigService(_InMemoryConfigRepository());
      await service.load();
      expect(
        () => service.setRecommendedDailyCount(0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('stores language and display name', () async {
      final repo = _InMemoryConfigRepository();
      final service = ConfigService(repo);
      await service.load();

      await service.setLanguageCode('es');
      await service.setDisplayName('  Jane  ');

      expect(service.languageCode, 'es');
      expect(service.displayName, 'Jane');

      final reloaded = await repo.load();
      expect(reloaded.languageCode, 'es');
      expect(reloaded.displayName, 'Jane');
    });

    test('rejects unsupported language codes', () async {
      final service = ConfigService(_InMemoryConfigRepository());
      await service.load();
      expect(
        () => service.setLanguageCode('fr'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
