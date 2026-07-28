import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/duel.dart';
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
                'source': sourceName(e.source),
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
              // Rows written before 0007 have no source; they were all taps.
              source: sourceFrom(row['source'] as String?),
            ),
        ];
      });
}

class SupabaseDuelGateway extends _SupabaseGateway implements DuelGateway {
  SupabaseDuelGateway(SupabaseClient? client, {DiagnosticsRecorder? onError})
      : super(client, onError);

  @override
  Future<List<Duel>> list() => _guard('duels.list', () async {
        final res = await _c.functions.invoke('duels', method: HttpMethod.get);
        final rows =
            ((res.data as Map<String, dynamic>)['duels'] as List<dynamic>?) ??
                const [];
        return [
          for (final row in rows.cast<Map<String, dynamic>>())
            Duel.fromJson(row),
        ];
      });

  @override
  Future<Duel?> preview(String code) => _guard('duels.preview', () async {
        final res = await _c.functions.invoke(
          'duels',
          method: HttpMethod.get,
          queryParameters: {'code': code},
        );
        final row = (res.data as Map<String, dynamic>)['duel'];
        return row == null
            ? null
            : Duel.fromJson((row as Map).cast<String, Object?>());
      });

  @override
  Future<Duel> create({required DuelKind kind}) =>
      _guard('duels.create', () async {
        final res = await _c.functions.invoke(
          'duels',
          body: {'action': 'create', 'kind': kind.wire},
        );
        final row = (res.data as Map<String, dynamic>)['duel'];
        if (row == null) throw const CloudUnavailable('create failed');
        return Duel.fromJson((row as Map).cast<String, Object?>());
      });

  @override
  Future<void> join(String code) async {
    try {
      await _c.functions.invoke('duels', body: {
        'action': 'join',
        'code': code,
      });
    } on FunctionException catch (e) {
      // 402 is the free-tier ceiling — a paywall moment, not a failure. 404/409
      // mean the code is wrong or the duel is over. Everything else is a real
      // fault and goes through the usual recording path.
      if (e.status == 402) throw const DuelLimitReached();
      if (e.status == 404) throw const DuelUnavailable('not-found');
      if (e.status == 409) throw const DuelUnavailable('ended');
      _onError?.call('duels.join', e, StackTrace.current);
      throw CloudUnavailable(e.toString());
    } catch (e, stack) {
      _onError?.call('duels.join', e, stack);
      throw CloudUnavailable(e.toString());
    }
  }

  @override
  Future<void> submitScore(String duelId, {int tapped = 0, int heard = 0}) =>
      _guard('duels.score', () async {
        await _c.functions.invoke('duels', body: {
          'action': 'score',
          'duel_id': duelId,
          'tapped': tapped,
          'heard': heard,
        });
      });

  @override
  Future<void> leave(String duelId) => _guard('duels.leave', () async {
        await _c.functions.invoke('duels', body: {
          'action': 'leave',
          'duel_id': duelId,
        });
      });
}

/// Live-duel transport over a Supabase Realtime **private** channel.
///
/// Private (`private: true`) is not optional: authorization comes from the RLS
/// policies in migration 0009, which are only consulted for private channels
/// and only when "Allow public access" is off in the project's Realtime
/// settings. Public channels would leave duel scores world-readable to anyone
/// who guesses a topic.
class SupabaseDuelChannel implements DuelChannel {
  SupabaseDuelChannel(this._client, {DiagnosticsRecorder? onError})
      : _onError = onError;

  final SupabaseClient? _client;
  final DiagnosticsRecorder? _onError;
  RealtimeChannel? _channel;

  static const _event = 'score';

  @override
  Stream<DuelLiveScore> join(String duelId) {
    final client = _client;
    final controller = StreamController<DuelLiveScore>();
    if (client == null) {
      controller.close();
      return controller.stream;
    }

    final channel = client.channel(
      'duel:$duelId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;

    channel
        .onBroadcast(
          event: _event,
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final count = (payload['count'] as num?)?.toInt();
            if (userId == null || count == null) return;
            // Ignore my own echo; the local count is already optimistic.
            if (userId == client.auth.currentUser?.id) return;
            controller.add(DuelLiveScore(userId: userId, count: count));
          },
        )
        .subscribe((status, error) {
      if (error != null) _onError?.call('duel.channel', error, StackTrace.current);
    });

    controller.onCancel = () async => channel.unsubscribe();
    return controller.stream;
  }

  @override
  Future<void> publish(String duelId, int count) async {
    final client = _client;
    final channel = _channel;
    if (client == null || channel == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: _event,
        payload: {'user_id': client.auth.currentUser?.id, 'count': count},
      );
    } catch (e, stack) {
      // A dropped liveness frame is survivable — the authoritative score still
      // goes through the edge function.
      _onError?.call('duel.publish', e, stack);
    }
  }

  @override
  Future<void> leave() async {
    await _channel?.unsubscribe();
    _channel = null;
  }
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
