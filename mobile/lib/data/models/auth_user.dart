import 'dart:convert';

enum AuthProvider { credentials, google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
  });

  final String id;
  final String displayName;
  final String email;
  final AuthProvider provider;

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'provider': provider.name,
      };

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        provider: AuthProvider.values.firstWhere(
          (p) => p.name == json['provider'],
          orElse: () => AuthProvider.credentials,
        ),
      );

  String encode() => jsonEncode(toJson());

  static AuthUser decode(String raw) =>
      AuthUser.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
