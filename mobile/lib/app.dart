import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'services/clouding_service.dart';
import 'services/config_service.dart';
import 'services/login_service.dart';

class CloudyLogApp extends StatelessWidget {
  const CloudyLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90E2)),
        useMaterial3: true,
      ),
      locale: config.isLoaded ? config.locale : null,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  String? _lastSyncedUserId;

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginService>();
    final clouding = context.watch<CloudingService>();
    final config = context.watch<ConfigService>();

    _syncCloudingToLogin(login, clouding);

    if (!login.isLoaded || !config.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!login.isLoggedIn) {
      return const LoginScreen();
    }
    if (!clouding.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const HomeScreen();
  }

  /// Keep CloudingService scoped to whichever user is currently signed in.
  /// Triggered from build via watches: any change to login state (sign-in,
  /// sign-out, account switch) flows through here exactly once per change.
  void _syncCloudingToLogin(
    LoginService login,
    CloudingService clouding,
  ) {
    if (!login.isLoaded) return;
    final currentUserId = login.currentUser?.id;
    if (currentUserId == _lastSyncedUserId) return;
    _lastSyncedUserId = currentUserId;
    // Defer to post-frame so we don't mutate ChangeNotifiers during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (currentUserId != null) {
        clouding.loadFor(currentUserId);
      } else {
        clouding.clear();
      }
    });
  }
}
