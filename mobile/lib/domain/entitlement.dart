/// The account's Pro entitlement as last reported by the server, cached
/// locally so Pro keeps working offline until it actually expires.
class Entitlement {
  const Entitlement({
    required this.status,
    required this.expiresAt,
    this.provider = 'mock',
  });

  /// 'active' | 'canceled' (canceled keeps Pro until [expiresAt]).
  final String status;
  final DateTime expiresAt;
  final String provider;

  bool isProAt(DateTime now) => expiresAt.isAfter(now);

  Map<String, Object?> toJson() => {
        'status': status,
        'expiresAt': expiresAt.toIso8601String(),
        'provider': provider,
      };

  factory Entitlement.fromJson(Map<String, Object?> json) => Entitlement(
        status: json['status'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        provider: (json['provider'] as String?) ?? 'mock',
      );
}
