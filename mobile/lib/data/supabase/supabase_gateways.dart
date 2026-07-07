import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entitlement.dart';
import '../../domain/puff_event.dart';
import '../gateways.dart';

/// All backend communication goes through the server API — Supabase Edge
/// Functions under `supabase/functions/`. The app never queries tables or
/// RPCs directly; the one exception is the Supabase Auth API itself
/// (anonymous sign-in, upgrade, sign-out), which is already a server API.

/// Wraps any Supabase/network error into [CloudUnavailable] so services stay
/// transport-agnostic.
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on CloudUnavailable {
    rethrow;
  } catch (e) {
    throw CloudUnavailable(e.toString());
  }
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient? _client;

  @override
  bool get isConfigured => _client != null;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw const CloudUnavailable('not configured');
    return client;
  }

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
  Future<AuthAccount?> ensureSession() => _guard(() async {
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
      _guard(() async {
        await ensureSession();
        await _c.auth.updateUser(
          UserAttributes(email: email, password: password),
        );
        return current!;
      });

  @override
  Future<void> deleteAccount() => _guard(() async {
        await _c.functions.invoke('account', method: HttpMethod.delete);
        await _c.auth.signOut();
      });
}

class SupabasePurchaseGateway implements PurchaseGateway {
  SupabasePurchaseGateway(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw const CloudUnavailable('not configured');
    return client;
  }

  @override
  Future<Entitlement?> fetch() => _guard(() async {
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

  Future<Entitlement> _act(String action) => _guard(() async {
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

class SupabaseEventsSyncGateway implements EventsSyncGateway {
  SupabaseEventsSyncGateway(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw const CloudUnavailable('not configured');
    return client;
  }

  @override
  Future<void> push(List<PuffEvent> events) => _guard(() async {
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
  Future<List<PuffEvent>> pullAll() => _guard(() async {
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

class SupabaseGlobalStatsGateway implements GlobalStatsGateway {
  SupabaseGlobalStatsGateway(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _c {
    final client = _client;
    if (client == null) throw const CloudUnavailable('not configured');
    return client;
  }

  @override
  Future<GlobalDailyStats?> latest() => _guard(() async {
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
}
