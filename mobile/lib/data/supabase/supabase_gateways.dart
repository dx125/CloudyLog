import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entitlement.dart';
import '../../domain/puff_event.dart';
import '../gateways.dart';

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
        await _c.rpc<void>('delete_my_account');
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
        final row = await _c
            .from('entitlements')
            .select('status, expires_at, provider')
            .maybeSingle();
        return row == null ? null : _toEntitlement(row);
      });

  @override
  Future<Entitlement> purchasePro() => _guard(() async {
        final row = await _c.rpc<Map<String, dynamic>>('activate_mock_pro');
        return _toEntitlement(row);
      });

  @override
  Future<Entitlement> cancelPro() => _guard(() async {
        final row = await _c.rpc<Map<String, dynamic>>('cancel_mock_pro');
        return _toEntitlement(row);
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
        await _c.from('events').upsert([
          for (final e in events)
            {
              'id': e.id,
              'type': e.type,
              'occurred_at': e.occurredAt.toUtc().toIso8601String(),
              'tags': e.tags,
              'device_id': e.deviceId,
            },
        ]);
      });

  @override
  Future<List<PuffEvent>> pullAll() => _guard(() async {
        final rows = await _c
            .from('events')
            .select('id, type, occurred_at, tags, device_id')
            .order('occurred_at', ascending: true);
        return [
          for (final row in rows)
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
        final row = await _c
            .from('daily_global_stats')
            .select('day, total_users, distribution')
            .order('day', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row == null) return null;
        return GlobalDailyStats(
          day: DateTime.parse(row['day'] as String),
          totalUsers: row['total_users'] as int,
          distribution: (row['distribution'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())),
        );
      });
}
