import 'package:intl/intl.dart';

import '../gateways.dart';
import '../models/auth_user.dart';
import '../models/friend_models.dart';
import '../models/subscription_status.dart';
import '../models/today_stats.dart';
import 'api_client.dart';

AuthUser _userFromJson(Map<String, Object?> json, AuthProvider provider) =>
    AuthUser(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      provider: provider,
      country: json['country'] as String?,
    );

class ApiAuthGateway implements AuthGateway {
  ApiAuthGateway(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/auth/signin', {
      'email': email,
      'password': password,
    });
    return _toSession(json);
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
    String? country,
  }) async {
    final json = await _api.post('/auth/signup', {
      'email': email,
      'password': password,
      'displayName': displayName,
      if (country != null) 'country': country,
    });
    return _toSession(json);
  }

  AuthSession _toSession(Map<String, Object?> json) => AuthSession(
        user: _userFromJson(
          json['user'] as Map<String, Object?>,
          AuthProvider.credentials,
        ),
        token: json['token'] as String,
      );
}

class ApiProfileGateway implements ProfileGateway {
  ApiProfileGateway(this._api);

  final ApiClient _api;

  @override
  Future<AuthUser> updateProfile({
    String? displayName,
    String? country,
  }) async {
    final json = await _api.patch('/me', {
      if (displayName != null) 'displayName': displayName,
      if (country != null) 'country': country,
    });
    return _userFromJson(
      json['user'] as Map<String, Object?>,
      AuthProvider.credentials,
    );
  }
}

class ApiSubscriptionGateway implements SubscriptionGateway {
  ApiSubscriptionGateway(this._api);

  final ApiClient _api;

  @override
  Future<SubscriptionStatus> fetch() async {
    return SubscriptionStatus.fromJson(await _api.get('/subscription'));
  }

  @override
  Future<SubscriptionStatus> activateMock() async {
    final json = await _api.post('/subscription/activate', {
      'provider': 'mock',
      'receipt': 'mock-${DateTime.now().millisecondsSinceEpoch}',
    });
    return SubscriptionStatus.fromJson(json);
  }

  @override
  Future<SubscriptionStatus> cancel() async {
    return SubscriptionStatus.fromJson(await _api.post('/subscription/cancel'));
  }
}

class ApiCloudingSyncGateway implements CloudingSyncGateway {
  ApiCloudingSyncGateway(this._api);

  final ApiClient _api;

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<Map<DateTime, int>> syncHistory(Map<DateTime, int> entries) async {
    final json = await _api.post('/cloudings/sync', {
      'entries': [
        for (final entry in entries.entries)
          {'day': _dayFormat.format(entry.key), 'count': entry.value},
      ],
    });
    final merged = <DateTime, int>{};
    for (final raw in (json['entries'] as List<Object?>)) {
      final map = raw as Map<String, Object?>;
      final day = DateTime.tryParse(map['day'] as String);
      if (day == null) continue;
      merged[DateTime(day.year, day.month, day.day)] =
          (map['count'] as num).toInt();
    }
    return merged;
  }

  @override
  Future<void> setToday(int count) async {
    await _api.put('/cloudings/today', {'count': count});
  }
}

class ApiStatsGateway implements StatsGateway {
  ApiStatsGateway(this._api);

  final ApiClient _api;

  @override
  Future<TodayStats> today(String scope) async {
    return TodayStats.fromJson(await _api.get('/stats/today?scope=$scope'));
  }
}

class ApiFriendsGateway implements FriendsGateway {
  ApiFriendsGateway(this._api);

  final ApiClient _api;

  @override
  Future<List<FriendToday>> friendsToday() async {
    final json = await _api.get('/friends/today');
    return [
      for (final raw in (json['friends'] as List<Object?>))
        FriendToday.fromJson(raw as Map<String, Object?>),
    ];
  }

  @override
  Future<List<PendingFriendRequest>> pendingRequests() async {
    final json = await _api.get('/friends/requests');
    return [
      for (final raw in (json['requests'] as List<Object?>))
        PendingFriendRequest.fromJson(raw as Map<String, Object?>),
    ];
  }

  @override
  Future<void> sendRequest(String email) async {
    await _api.post('/friends/requests', {'email': email});
  }

  @override
  Future<void> respond({
    required String requesterId,
    required bool accept,
  }) async {
    await _api.post('/friends/requests/$requesterId/respond', {
      'accept': accept,
    });
  }
}
