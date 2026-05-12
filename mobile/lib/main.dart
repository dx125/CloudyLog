import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/auth_repository.dart';
import 'data/clouding_repository.dart';
import 'data/config_repository.dart';
import 'services/clouding_service.dart';
import 'services/config_service.dart';
import 'services/login_service.dart';
import 'services/share_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final cloudingRepo = SharedPrefsCloudingRepository(prefs);
  final configRepo = SharedPrefsConfigRepository(prefs);
  final authRepo = SharedPrefsAuthRepository(prefs);

  // CloudingService is constructed but not loaded here — it needs a userId,
  // which we only know after LoginService resolves. _RootGate triggers
  // `loadFor(userId)` once authentication completes.
  final cloudingService = CloudingService(cloudingRepo);
  final configService = ConfigService(configRepo);
  final loginService = LoginService(authRepo);
  await Future.wait([configService.load(), loginService.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CloudingService>.value(value: cloudingService),
        ChangeNotifierProvider<ConfigService>.value(value: configService),
        ChangeNotifierProvider<LoginService>.value(value: loginService),
        Provider<ShareService>.value(value: const SharePlusShareService()),
      ],
      child: const CloudyLogApp(),
    ),
  );
}
