import 'models/auth_user.dart';
import 'models/friend_models.dart';
import 'models/subscription_status.dart';
import 'models/today_stats.dart';

/// Backend auth. Implementations throw [ApiException]-style errors; services
/// translate them into user-facing results.
abstract class AuthGateway {
  Future<AuthSession> signIn({required String email, required String password});
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
    String? country,
  });
}

abstract class ProfileGateway {
  Future<AuthUser> updateProfile({String? displayName, String? country});
}

abstract class SubscriptionGateway {
  Future<SubscriptionStatus> fetch();

  /// Development billing: activates Pro through the backend's mock provider.
  /// Swapped for store-receipt validation when real billing lands.
  Future<SubscriptionStatus> activateMock();
  Future<SubscriptionStatus> cancel();
}

abstract class CloudingSyncGateway {
  /// Uploads local history; the server merges by keeping the larger count
  /// per day and returns the full merged history.
  Future<Map<DateTime, int>> syncHistory(Map<DateTime, int> entries);

  /// Absolute write of today's count (source of truth is this device).
  Future<void> setToday(int count);
}

abstract class StatsGateway {
  /// [scope] is 'worldwide' or 'country'.
  Future<TodayStats> today(String scope);
}

abstract class FriendsGateway {
  Future<List<FriendToday>> friendsToday();
  Future<List<PendingFriendRequest>> pendingRequests();
  Future<void> sendRequest(String email);
  Future<void> respond({required String requesterId, required bool accept});
}
