import 'package:cloudy_log/data/api/api_client.dart';
import 'package:cloudy_log/data/models/subscription_status.dart';
import 'package:cloudy_log/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('SubscriptionService', () {
    late InMemorySubscriptionRepository repo;
    late FakeSubscriptionGateway gateway;
    late SubscriptionService service;

    setUp(() async {
      repo = InMemorySubscriptionRepository();
      gateway = FakeSubscriptionGateway();
      service = SubscriptionService(repo, gateway);
      await service.load();
    });

    test('defaults to free', () {
      expect(service.isPro, isFalse);
      expect(service.status.tier, 'free');
    });

    test('purchasePro activates and caches the entitlement', () async {
      final ok = await service.purchasePro();
      expect(ok, isTrue);
      expect(service.isPro, isTrue);
      expect(repo.status?.tier, 'pro');
    });

    test('purchase failure keeps free tier', () async {
      gateway.failWith = const ApiException.network();
      final ok = await service.purchasePro();
      expect(ok, isFalse);
      expect(service.isPro, isFalse);
    });

    test('cancel keeps pro until expiry', () async {
      await service.purchasePro();
      final ok = await service.cancel();
      expect(ok, isTrue);
      expect(service.status.status, 'canceled');
      expect(service.isPro, isTrue);
    });

    test('cached pro past its expiry is treated as free', () async {
      repo.status = SubscriptionStatus(
        tier: 'pro',
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await service.load();
      expect(service.isPro, isFalse);
    });

    test('refresh swallows network errors and keeps cache', () async {
      await service.purchasePro();
      gateway.failWith = const ApiException.network();
      await service.refresh();
      expect(service.isPro, isTrue);
    });

    test('clearLocal drops the entitlement', () async {
      await service.purchasePro();
      await service.clearLocal();
      expect(service.isPro, isFalse);
      expect(repo.status, isNull);
    });
  });
}
