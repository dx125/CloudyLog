import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'services/clouding_service.dart';
import 'services/config_service.dart';

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

/// Free tier works without an account, so the app opens straight into the
/// tracker. Sign-in only appears inside the Pro upgrade flow.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final clouding = context.watch<CloudingService>();
    final config = context.watch<ConfigService>();

    if (!config.isLoaded || !clouding.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const HomeScreen();
  }
}
