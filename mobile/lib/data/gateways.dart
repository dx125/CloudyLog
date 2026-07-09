import '../domain/entitlement.dart';
import '../domain/puff_event.dart';

/// Thrown by any gateway when the cloud can't be reached or isn't configured.
/// The app is offline-first: callers catch this and carry on — a tap must
/// register in airplane mode, in a basement, forever.
class CloudUnavailable implements Exception {
  const CloudUnavailable([this.message = 'cloud unavailable']);

  final String message;

  @override
  String toString() => 'CloudUnavailable($message)';
}

class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.isAnonymous,
    this.email,
  });

  final String id;
  final bool isAnonymous;
  final String? email;
}

/// Supabase auth: every user starts as an anonymous session and is upgraded
/// in place (same user id, so data continuity is free).
abstract class AuthGateway {
  /// True when a Supabase URL/key were provided at build time.
  bool get isConfigured;

  AuthAccount? get current;

  /// Signs in anonymously when no session exists. Safe to call repeatedly.
  Future<AuthAccount?> ensureSession();

  /// Attaches email+password credentials to the anonymous user.
  Future<AuthAccount> upgrade({required String email, required String password});

  /// Signs in to an existing email account, replacing the current session
  /// (e.g. reclaiming Pro on a new phone).
  Future<AuthAccount> signIn({required String email, required String password});

  /// Ends the current session and starts a fresh anonymous one, so the core
  /// loop and world-stats reporting keep working after sign-out.
  Future<void> signOut();

  /// Deletes the auth user and everything cascading from it, then drops the
  /// local session ("deletion is one tap and total").
  Future<void> deleteAccount();
}

/// The RevenueCat-shaped seam (handoff §7: payments go through RevenueCat;
/// don't hand-roll receipts). The dev implementation calls the backend's mock
/// RPCs; the RevenueCat implementation replaces this one class later.
abstract class PurchaseGateway {
  Future<Entitlement?> fetch();
  Future<Entitlement> purchasePro();
  Future<Entitlement> cancelPro();
}

abstract class EventsSyncGateway {
  /// Idempotent upsert by client-generated UUID.
  Future<void> push(List<PuffEvent> events);

  /// Full pull for restore-onto-a-new-device.
  Future<List<PuffEvent>> pullAll();
}

class GlobalDailyStats {
  const GlobalDailyStats({
    required this.day,
    required this.totalUsers,
    required this.distribution,
  });

  final DateTime day;
  final int totalUsers;
  final Map<String, int> distribution;
}

/// One local day's toot total — the entirety of what a stats report shares.
class DailyTootCount {
  const DailyTootCount({required this.day, required this.count});

  final DateTime day;
  final int count;
}

abstract class GlobalStatsGateway {
  /// Latest anonymous aggregate snapshot; null when none exists yet.
  Future<GlobalDailyStats?> latest();

  /// Upserts this user's per-day counts into the world aggregate input.
  /// Free and Pro alike — the histogram needs everyone (raw event sync stays
  /// Pro-only; this is one number per day, not sync).
  Future<void> reportDaily(List<DailyTootCount> days);
}
