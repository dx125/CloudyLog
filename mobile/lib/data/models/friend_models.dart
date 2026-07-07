class FriendToday {
  const FriendToday({
    required this.userId,
    required this.displayName,
    required this.count,
  });

  final String userId;
  final String displayName;
  final int count;

  factory FriendToday.fromJson(Map<String, Object?> json) => FriendToday(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        count: (json['count'] as num).toInt(),
      );
}

class PendingFriendRequest {
  const PendingFriendRequest({
    required this.requesterId,
    required this.requesterDisplayName,
    required this.requesterEmail,
  });

  final String requesterId;
  final String requesterDisplayName;
  final String requesterEmail;

  factory PendingFriendRequest.fromJson(Map<String, Object?> json) =>
      PendingFriendRequest(
        requesterId: json['requesterId'] as String,
        requesterDisplayName: json['requesterDisplayName'] as String,
        requesterEmail: json['requesterEmail'] as String,
      );
}
