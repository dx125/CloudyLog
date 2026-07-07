import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/drift/drift_event_store.dart';
import 'data/drift/puff_database.dart';
import 'data/event_store.dart';
import 'data/gateways.dart';
import 'data/settings_repository.dart';
import 'data/supabase/supabase_gateways.dart';
import 'services/auth_service.dart';
import 'services/entitlement_service.dart';
import 'services/settings_service.dart';
import 'services/share_service.dart';
import 'services/stats_service.dart';
import 'services/sync_service.dart';
import 'services/tap_service.dart';

/// Supabase endpoint, compiled in at build time. Provide via an env file
/// (copy `.env.example` to `.env`, then `--dart-define-from-file=.env`) or
/// pass the keys directly with `--dart-define=PUFF_SUPABASE_URL=...`.
/// Left empty, the app runs 100% on-device — the free tier needs no cloud at
/// all, and Pro flows degrade to "try again online".
const String _supabaseUrl = String.fromEnvironment('PUFF_SUPABASE_URL');
const String _supabaseAnonKey =
    String.fromEnvironment('PUFF_SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SharedPrefsSettingsRepository(prefs);
  final EventStore store = DriftEventStore(PuffDatabase(openPuffDatabase()));

  // The cloud is optional at startup — never a dependency of the core loop.
  SupabaseClient? supabase;
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
      );
      supabase = Supabase.instance.client;
    } catch (_) {
      supabase = null; // Offline/misconfigured: free tier is unaffected.
    }
  }

  final settingsService = SettingsService(settingsRepo);
  final authService = AuthService(SupabaseAuthGateway(supabase));
  final entitlementService = EntitlementService(
    settingsRepo,
    SupabasePurchaseGateway(supabase),
  );
  final tapService = TapService(store, deviceId: await settingsRepo.deviceId());
  final statsService = StatsService(store);
  final syncService = SyncService(
    store,
    SupabaseEventsSyncGateway(supabase),
    shouldSync: () => entitlementService.isPro && authService.hasSession,
  );

  await Future.wait([
    settingsService.load(),
    entitlementService.load(),
    tapService.load(),
  ]);

  // Mirror local changes to the cloud for Pro users. schedulePush debounces
  // past the quick-tag window so a tag edit rides along with its tap.
  tapService.addListener(syncService.schedulePush);

  // Background cloud warm-up: session, fresh entitlement, pending events.
  Future(() async {
    await authService.ensureSession();
    if (!authService.hasSession) return;
    await entitlementService.refresh();
    if (entitlementService.isPro) await syncService.pushPending();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<EntitlementService>.value(
          value: entitlementService,
        ),
        ChangeNotifierProvider<TapService>.value(value: tapService),
        ChangeNotifierProvider<SyncService>.value(value: syncService),
        Provider<StatsService>.value(value: statsService),
        Provider<ShareService>.value(value: const SharePlusShareService()),
        Provider<GlobalStatsGateway>.value(
          value: SupabaseGlobalStatsGateway(supabase),
        ),
      ],
      child: const PuffApp(),
    ),
  );
}
