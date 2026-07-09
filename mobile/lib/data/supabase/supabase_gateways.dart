import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entitlement.dart';
import '../../domain/puff_event.dart';
import '../diagnostics_store.dart';
import '../gateways.dart';

/// All backend communication goes through the server API — Supabase Edge
/// Functions under `supabase/functions/`. The app never queries tables or
/// RPCs directly; the one exception is the Supabase Auth API itself
/// (anonymous sign-in, upgrade, sign-out), which is already a server API.

/// Shared plumbing: the null-client guard and error wrapping. Services stay
/// transport-agnostic (they see only [CloudUnavailable]), but real failures
/// are first reported through [onError] so they land in Settings →
/// Diagnostics instead of vanishing into the offline-first fallbacks.
/// Running without cloud config is a supported mode, not an error — the
/// "not configured" throw is never recorded.
abstract class _SupabaseGateway {
  _SupabaseGateway(this._client, this._onError);

  final SupabaseClient? _client;
  final DiagnosticsRecorder? _onError;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw const CloudUnavailable('not configured');
    return client;
  }

  Future<T> _guard<T>(String source, Future<T> Function() action) async {
    try {
      return await action();
    } on CloudUnavailable {
      rethrow;
    } catch (e, stack) {
      _onError?.call(source, e, stack);
      throw CloudUnavailable(e.toString());
    }
  }
}

class SupabaseAuthGateway extends _SupabaseGateway implements AuthGateway {
  SupabaseAuthGateway(SupabaseClient? client, {DiagnosticsRecorder? onError})
      : super(client, onError);

  @override
  bool get isConfigured => _client != null;

  @override
  AuthAccount? get current {
    final user = _client?.auth.currentUser;
    if (user == null) return null;
    return AuthAccount(
      id: user.id,
      isAnonymous: user.isAnonymous,
      email: (user.email?.isEmpty ?? true) ? null : user.email,
    );
  }

  @override
  Future<AuthAccount?> ensureSession() => _guard('auth.ensureSession', () async {
        if (_c.auth.currentSession == null) {
          await _c.auth.signInAnonymously();
        }
        return current;
      });

  @override
  Future<AuthAccount> upgrade({
    required String email,
    required String password,
  }) =>
      _guard('auth.upgrade', () async {
        await ensureSession();
        await _c.auth.updateUser(
          UserAttributes(email: email, password: password),
        );
        return current!;
      });

  @override
  Future<AuthAccount> signIn({
    required String email,
    required String password,
  }) =>
      _guard('auth.signIn', () async {
        await _c.auth.signInWithPassword(email: email, password: password);
        return current!;
      });

  @override
  Future<void> signOut() => _guard('auth.signOut', () async {
        await _c.auth.signOut();
        // Drop straight back onto an anonymous session so the app stays
        // cloud-capable (world-stats reporting) without a real account.
        await _c.auth.signInAnonymously();
      });

  @override
  Future<void> deleteAccount() => _guard('auth.deleteAccount', () async {
        await _c.functions.invoke('account', method: HttpMethod.delete);
        await _c.auth.signOut();
      });
}

class SupabasePurchaseGateway extends _SupabaseGateway
    implements PurchaseGateway {
  SupabasePurchaseGateway(SupabaseClient? client, {DiagnosticsRecorder? onError})
      : super(client, onError);

  @override
  Future<Entitlement?> fetch() => _guard('purchases.fetch', () async {
        final res =
            await _c.functions.invoke('entitlements', method: HttpMethod.get);
        final row = (res.data as Map<String, dynamic>)['entitlement'];
        return row == null
            ? null
            : _toEntitlement((row as Map).cast<String, dynamic>());
      });

  @override
  Future<Entitlement> purchasePro() => _act('purchase');

  @override
  Future<Entitlement> cancelPro() => _act('cancel');

  Future<Entitlement> _act(String action) =>
      _guard('purchases.$action', () async {
        final res = await _c.functions
            .invoke('entitlements', body: {'action': action});
        final row = (res.data as Map<String, dynamic>)['entitlement'];
        return _toEntitlement((row as Map).cast<String, dynamic>());
      });

  Entitlement _toEntitlement(Map<String, dynamic> row) => Entitlement(
        status: row['status'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
        provider: (row['provider'] as String?) ?? 'mock',
      );
}

class SupabaseEventsSyncGateway extends _SupabaseGateway
    implements EventsSyncGateway {
  SupabaseEventsSyncGateway(SupabaseClient? client,
      {DiagnosticsRecorder? onError})
      : super(client, onError);

  @override
  Future<void> push(List<PuffEvent> events) => _guard('sync.push', () async {
        if (events.isEmpty) return;
        await _c.functions.invoke('sync-events', body: {
          'events': [
            for (final e in events)
              {
                'id': e.id,
                'type': e.type,
                'occurred_at': e.occurredAt.toUtc().toIso8601String(),
                'tags': e.tags,
                'device_id': e.deviceId,
              },
          ],
        });
      });

  @override
  Future<List<PuffEvent>> pullAll() => _guard('sync.pullAll', () async {
        final res =
            await _c.functions.invoke('sync-events', method: HttpMethod.get);
        final rows =
            ((res.data as Map<String, dynamic>)['events'] as List<dynamic>?) ??
                const [];
        return [
          for (final row in rows.cast<Map<String, dynamic>>())
            PuffEvent(
              id: row['id'] as String,
              type: row['type'] as String,
              occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
              tags: ((row['tags'] as List<dynamic>?) ?? const [])
                  .cast<String>(),
              deviceId: (row['device_id'] as String?) ?? '',
            ),
        ];
      });
}

class SupabaseGlobalStatsGateway extends _SupabaseGateway
    implements GlobalStatsGateway {
  SupabaseGlobalStatsGateway(SupabaseClient? client,
      {DiagnosticsRecorder? onError})
      : super(client, onError);

  @override
  Future<GlobalDailyStats?> latest() => _guard('stats.latest', () async {
        final res =
            await _c.functions.invoke('global-stats', method: HttpMethod.get);
        final row = (res.data as Map<String, dynamic>)['stats'];
        if (row == null) return null;
        final stats = (row as Map).cast<String, dynamic>();
        return GlobalDailyStats(
          day: DateTime.parse(stats['day'] as String),
          totalUsers: stats['total_users'] as int,
          distribution: (stats['distribution'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())),
        );
      });

  @override
  Future<void> reportDaily(List<DailyTootCount> days) =>
      _guard('stats.report', () async {
        if (days.isEmpty) return;
        await _c.functions.invoke('report-stats', body: {
          'days': [
            for (final d in days) {'day': dayKey(d.day), 'count': d.count},
          ],
        });
      });
}
