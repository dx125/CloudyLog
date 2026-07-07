import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/api/api_client.dart';
import 'data/api/api_gateways.dart';
import 'data/auth_repository.dart';
import 'data/clouding_repository.dart';
import 'data/config_repository.dart';
import 'data/gateways.dart';
import 'data/subscription_repository.dart';
import 'services/clouding_service.dart';
import 'services/config_service.dart';
import 'services/login_service.dart';
import 'services/share_service.dart';
import 'services/subscription_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final cloudingRepo = SharedPrefsCloudingRepository(prefs);
  final configRepo = SharedPrefsConfigRepository(prefs);
  final authRepo = SharedPrefsAuthRepository(prefs);
  final subscriptionRepo = SharedPrefsSubscriptionRepository(prefs);

  final api = ApiClient();
  final statsGateway = ApiStatsGateway(api);
  final friendsGateway = ApiFriendsGateway(api);

  final cloudingService = CloudingService(cloudingRepo);
  final configService = ConfigService(configRepo);
  final loginService = LoginService(
    authRepo,
    ApiAuthGateway(api),
    ApiProfileGateway(api),
    api,
  );
  final subscriptionService = SubscriptionService(
    subscriptionRepo,
    ApiSubscriptionGateway(api),
  );
  final syncService = SyncService(ApiCloudingSyncGateway(api), cloudingRepo);

  await Future.wait([
    configService.load(),
    loginService.load(),
    subscriptionService.load(),
    // Free tier needs no account: device data lives under the local profile.
    cloudingService.loadFor(kLocalProfileId),
  ]);

  // Mirror local changes to the cloud for signed-in Pro users. pushToday is
  // an absolute write and deduplicates, so notifying on loads is harmless.
  cloudingService.addListener(() {
    if (loginService.isLoggedIn && subscriptionService.isPro) {
      syncService.pushToday(cloudingService.today, cloudingService.todayCount);
    }
  });

  // Signed-in Pro users reconcile with the server in the background at start.
  if (loginService.isLoggedIn && subscriptionService.isPro) {
    Future(() async {
      await subscriptionService.refresh();
      if (!subscriptionService.isPro) return;
      final changed = await syncService.syncAll(kLocalProfileId);
      if (changed) await cloudingService.loadFor(kLocalProfileId);
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CloudingService>.value(value: cloudingService),
        ChangeNotifierProvider<ConfigService>.value(value: configService),
        ChangeNotifierProvider<LoginService>.value(value: loginService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: subscriptionService,
        ),
        ChangeNotifierProvider<SyncService>.value(value: syncService),
        Provider<ShareService>.value(value: const SharePlusShareService()),
        Provider<StatsGateway>.value(value: statsGateway),
        Provider<FriendsGateway>.value(value: friendsGateway),
      ],
      child: const CloudyLogApp(),
    ),
  );
}
