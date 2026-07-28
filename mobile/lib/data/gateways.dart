import 'dart:typed_data';

import '../domain/acoustic.dart';
import '../domain/duel.dart';
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

/// Thrown when the free tier's one-duel limit is hit — the paywall moment, not
/// an error. Distinct from [CloudUnavailable] so the UI can offer Pro rather
/// than "try again later".
class DuelLimitReached implements Exception {
  const DuelLimitReached();

  @override
  String toString() => 'DuelLimitReached()';
}

/// Thrown when a join code matches nothing, or the duel already ended.
class DuelUnavailable implements Exception {
  const DuelUnavailable(this.reason);

  /// 'not-found' | 'ended'
  final String reason;

  @override
  String toString() => 'DuelUnavailable($reason)';
}

/// Duels, over the `duels` edge function. Scores are *submitted* and validated
/// server-side — the server has no raw events for free users, so it can't
/// derive them (see migration 0008).
abstract class DuelGateway {
  Future<List<Duel>> list();

  /// Looks up a duel by join code without joining it.
  Future<Duel?> preview(String code);

  /// Pro-gated by RLS, so a free caller gets [CloudUnavailable] from the 403.
  Future<Duel> create({required DuelKind kind});

  /// Free tier may hold one duel; beyond that this throws [DuelLimitReached].
  Future<void> join(String code);

  Future<void> submitScore(String duelId, {int tapped = 0, int heard = 0});

  Future<void> leave(String duelId);
}

/// Live-duel transport. Broadcast carries *liveness only* — the authoritative
/// score always goes through [DuelGateway.submitScore], never a message a peer
/// could forge.
abstract class DuelChannel {
  /// Opponent score updates on this duel's private channel.
  Stream<DuelLiveScore> join(String duelId);

  /// Publishes my current count. Callers must throttle: the project-wide
  /// Realtime budget is 500 msg/s, which is only ~250 concurrent live duels at
  /// one message per client per second.
  Future<void> publish(String duelId, int count);

  Future<void> leave();
}

class DuelLiveScore {
  const DuelLiveScore({required this.userId, required this.count});

  final String userId;
  final int count;
}

/// Raw microphone access, as 16 kHz mono PCM16 frames.
///
/// **Every speech-DSP feature must be disabled** in the implementation —
/// automatic gain control, noise suppression and echo cancellation are all
/// tuned to preserve speech and discard everything else. To a noise suppressor
/// a toot is textbook noise, so it would attenuate the very thing we're trying
/// to hear; AGC would flatten the loudness that distinguishes a thunder from a
/// squeak. The training corpus must be captured with these same settings, or
/// the model learns a signal chain the app never reproduces.
abstract class AudioCaptureGateway {
  Future<bool> hasPermission();

  /// Prompts if needed. False means denied — the caller degrades gracefully;
  /// the tap loop must keep working regardless.
  Future<bool> requestPermission();

  /// Frames of PCM16 samples at [kAcousticSampleRate]. Ends when [stop] is
  /// called or the platform interrupts capture (a call, another app).
  Stream<Int16List> start();

  Future<void> stop();
}

/// The acoustic model: YAMNet's frozen trunk plus our trained head.
///
/// Implementations run inference off the main isolate — the tap loop's
/// sub-100 ms guarantee must never share a thread with a model.
abstract class AcousticClassifier {
  /// Loads the model. Safe to call repeatedly; the second call is a no-op.
  Future<void> load();

  /// Classifies exactly [kAcousticWindowSamples] float samples in [-1, 1].
  Future<AcousticVerdict> classify(Float32List window);

  Future<void> dispose();
}

abstract class GlobalStatsGateway {
  /// Latest anonymous aggregate snapshot; null when none exists yet.
  Future<GlobalDailyStats?> latest();

  /// Upserts this user's per-day counts into the world aggregate input.
  /// Free and Pro alike — the histogram needs everyone (raw event sync stays
  /// Pro-only; this is one number per day, not sync).
  Future<void> reportDaily(List<DailyTootCount> days);
}
