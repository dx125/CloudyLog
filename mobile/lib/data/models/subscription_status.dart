import 'dart:convert';

/// Snapshot of the account's subscription as last reported by the server.
/// [isProAt] re-checks the expiry locally so a stale cached "pro" downgrades
/// itself once the entitlement lapses, even while offline.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.tier,
    this.status,
    this.expiresAt,
  });

  static const SubscriptionStatus free = SubscriptionStatus(tier: 'free');

  /// 'free' | 'pro'
  final String tier;

  /// 'active' | 'canceled' | null (never subscribed)
  final String? status;
  final DateTime? expiresAt;

  bool isProAt(DateTime now) {
    if (tier != 'pro') return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(now);
  }

  Map<String, Object?> toJson() => {
        'tier': tier,
        'status': status,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory SubscriptionStatus.fromJson(Map<String, Object?> json) =>
      SubscriptionStatus(
        tier: (json['tier'] as String?) ?? 'free',
        status: json['status'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.tryParse(json['expiresAt'] as String),
      );

  String encode() => jsonEncode(toJson());

  static SubscriptionStatus decode(String raw) =>
      SubscriptionStatus.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
