import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/entitlement.dart';
import 'package:puff/services/entitlement_service.dart';

import 'fakes.dart';

void main() {
  group('EntitlementService', () {
    late InMemorySettingsRepository settings;
    late FakePurchaseGateway purchases;
    late DateTime now;
    late EntitlementService service;

    setUp(() async {
      settings = InMemorySettingsRepository();
      purchases = FakePurchaseGateway();
      now = DateTime(2026, 7, 7, 12, 0);
      purchases.now = () => now;
      service = EntitlementService(settings, purchases, clock: () => now);
      await service.load();
    });

    test('defaults to free', () {
      expect(service.isPro, isFalse);
    });

    test('purchase activates Pro and caches it', () async {
      expect(await service.purchasePro(), isTrue);
      expect(service.isPro, isTrue);
      expect(settings.entitlement, isNotNull);
    });

    test('purchase fails gracefully offline', () async {
      purchases.offline = true;
      expect(await service.purchasePro(), isFalse);
      expect(service.isPro, isFalse);
    });

    test('cancel keeps Pro until expiry', () async {
      await service.purchasePro();
      expect(await service.cancelPro(), isTrue);
      expect(service.entitlement?.status, 'canceled');
      expect(service.isPro, isTrue);
      now = now.add(const Duration(days: 31));
      expect(service.isPro, isFalse);
    });

    test('a cached entitlement self-downgrades past expiry', () async {
      settings.entitlement = Entitlement(
        status: 'active',
        expiresAt: now.subtract(const Duration(days: 1)),
      );
      await service.load();
      expect(service.isPro, isFalse);
    });

    test('refresh keeps the cache when offline', () async {
      await service.purchasePro();
      purchases.offline = true;
      await service.refresh();
      expect(service.isPro, isTrue);
    });

    test('refresh picks up the server state', () async {
      purchases.remote = Entitlement(
        status: 'active',
        expiresAt: now.add(const Duration(days: 10)),
      );
      await service.refresh();
      expect(service.isPro, isTrue);
    });
  });
}
