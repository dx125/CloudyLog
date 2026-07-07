import 'dart:convert';

enum AuthProvider { credentials, google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    this.country,
  });

  final String id;
  final String displayName;
  final String email;
  final AuthProvider provider;

  /// ISO 3166-1 alpha-2, uppercase. Null when the account has no country.
  final String? country;

  AuthUser copyWith({String? displayName, String? country}) => AuthUser(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email,
        provider: provider,
        country: country ?? this.country,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'provider': provider.name,
        'country': country,
      };

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        provider: AuthProvider.values.firstWhere(
          (p) => p.name == json['provider'],
          orElse: () => AuthProvider.credentials,
        ),
        country: json['country'] as String?,
      );

  String encode() => jsonEncode(toJson());

  static AuthUser decode(String raw) =>
      AuthUser.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

/// A signed-in user plus the Bearer token that authenticates them.
class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AuthUser user;
  final String token;
}
