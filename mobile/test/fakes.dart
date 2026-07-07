import 'package:cloudy_log/data/api/api_client.dart';
import 'package:cloudy_log/data/auth_repository.dart';
import 'package:cloudy_log/data/clouding_repository.dart';
import 'package:cloudy_log/data/gateways.dart';
import 'package:cloudy_log/data/models/auth_user.dart';
import 'package:cloudy_log/data/models/subscription_status.dart';
import 'package:cloudy_log/data/subscription_repository.dart';

class InMemoryAuthRepository implements AuthRepository {
  AuthUser? user;
  String? token;

  @override
  Future<AuthUser?> loadUser() async => user;

  @override
  Future<void> saveUser(AuthUser value) async => user = value;

  @override
  Future<String?> loadToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clear() async {
    user = null;
    token = null;
  }
}

class InMemorySubscriptionRepository implements SubscriptionRepository {
  SubscriptionStatus? status;

  @override
  Future<SubscriptionStatus?> load() async => status;

  @override
  Future<void> save(SubscriptionStatus value) async => status = value;

  @override
  Future<void> clear() async => status = null;
}

class InMemoryCloudingRepository implements CloudingRepository {
  final Map<String, Map<DateTime, int>> store = {};

  Map<DateTime, int> _forUser(String userId) =>
      store.putIfAbsent(userId, () => {});

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<int> getCountFor(String userId, DateTime date) async =>
      _forUser(userId)[_day(date)] ?? 0;

  @override
  Future<void> setCountFor(String userId, DateTime date, int count) async {
    _forUser(userId)[_day(date)] = count;
  }

  @override
  Future<Map<DateTime, int>> getAllEntries(String userId) async =>
      Map.of(_forUser(userId));
}

class FakeAuthGateway implements AuthGateway {
  ApiException? failWith;
  int signInCalls = 0;
  int signUpCalls = 0;
  String? lastCountry;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final error = failWith;
    if (error != null) throw error;
    return AuthSession(
      user: AuthUser(
        id: 'u1',
        displayName: 'Alice',
        email: email,
        provider: AuthProvider.credentials,
        country: 'US',
      ),
      token: 'token-1',
    );
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
    String? country,
  }) async {
    signUpCalls++;
    lastCountry = country;
    final error = failWith;
    if (error != null) throw error;
    return AuthSession(
      user: AuthUser(
        id: 'u2',
        displayName: displayName,
        email: email,
        provider: AuthProvider.credentials,
        country: country,
      ),
      token: 'token-2',
    );
  }
}

class FakeProfileGateway implements ProfileGateway {
  String? lastCountry;

  @override
  Future<AuthUser> updateProfile({
    String? displayName,
    String? country,
  }) async {
    lastCountry = country;
    return AuthUser(
      id: 'u1',
      displayName: displayName ?? 'Alice',
      email: 'a@b.c',
      provider: AuthProvider.credentials,
      country: country,
    );
  }
}

class FakeSubscriptionGateway implements SubscriptionGateway {
  SubscriptionStatus remote = SubscriptionStatus.free;
  ApiException? failWith;

  @override
  Future<SubscriptionStatus> fetch() async {
    final error = failWith;
    if (error != null) throw error;
    return remote;
  }

  @override
  Future<SubscriptionStatus> activateMock() async {
    final error = failWith;
    if (error != null) throw error;
    remote = SubscriptionStatus(
      tier: 'pro',
      status: 'active',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    return remote;
  }

  @override
  Future<SubscriptionStatus> cancel() async {
    final error = failWith;
    if (error != null) throw error;
    remote = SubscriptionStatus(
      tier: 'pro',
      status: 'canceled',
      expiresAt: remote.expiresAt,
    );
    return remote;
  }
}

class FakeCloudingSyncGateway implements CloudingSyncGateway {
  final Map<DateTime, int> server = {};
  ApiException? failWith;
  final List<int> pushedTodayCounts = [];

  @override
  Future<Map<DateTime, int>> syncHistory(Map<DateTime, int> entries) async {
    final error = failWith;
    if (error != null) throw error;
    for (final entry in entries.entries) {
      if (entry.value == 0) continue;
      final existing = server[entry.key] ?? 0;
      server[entry.key] = entry.value > existing ? entry.value : existing;
    }
    return Map.of(server);
  }

  @override
  Future<void> setToday(int count) async {
    final error = failWith;
    if (error != null) throw error;
    pushedTodayCounts.add(count);
  }
}
