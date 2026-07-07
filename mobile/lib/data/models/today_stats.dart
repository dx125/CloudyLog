/// Server-computed comparison of today's count against other users.
class TodayStats {
  const TodayStats({
    required this.day,
    required this.scope,
    required this.count,
    this.country,
    this.percentile,
    this.totalUsers,
  });

  final String day;

  /// 'worldwide' | 'country'
  final String scope;
  final String? country;
  final int count;

  /// 0-100 midpoint percentile rank; null when no aggregate exists yet.
  final int? percentile;
  final int? totalUsers;

  factory TodayStats.fromJson(Map<String, Object?> json) => TodayStats(
        day: json['day'] as String,
        scope: json['scope'] as String,
        country: json['country'] as String?,
        count: (json['count'] as num).toInt(),
        percentile: (json['percentile'] as num?)?.toInt(),
        totalUsers: (json['totalUsers'] as num?)?.toInt(),
      );
}
