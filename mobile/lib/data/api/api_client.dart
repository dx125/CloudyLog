import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Backend base URL. Override per environment with:
/// `flutter run --dart-define=CLOUDYLOG_API_URL=https://api.example.com`
/// (Android emulators reach the host machine at http://10.0.2.2:8787.)
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'CLOUDYLOG_API_URL',
  defaultValue: 'http://localhost:8787',
);

/// Structured API failure. [code] carries the backend's machine-readable
/// error (e.g. 'invalid_credentials', 'pro_required'); [isNetwork] marks
/// transport-level failures where no response arrived at all.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.statusCode,
    this.isNetwork = false,
  });

  const ApiException.network() : this(code: 'network_error', isNetwork: true);

  final String code;
  final int? statusCode;
  final bool isNetwork;

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : _baseUrl = (baseUrl ?? kDefaultApiBaseUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  String? _token;

  /// Bearer token for authenticated calls; null clears it.
  set token(String? value) => _token = value;
  bool get hasToken => _token != null;

  Future<Map<String, Object?>> get(String path) => _send('GET', path);

  Future<Map<String, Object?>> post(String path, [Object? body]) =>
      _send('POST', path, body);

  Future<Map<String, Object?>> put(String path, [Object? body]) =>
      _send('PUT', path, body);

  Future<Map<String, Object?>> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);

  Future<Map<String, Object?>> _send(
    String method,
    String path, [
    Object? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
    final token = _token;
    if (token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      final streamed = await _http.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException.network();
    }

    Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, Object?>;
    } catch (_) {
      decoded = const {};
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        code: (decoded['error'] as String?) ?? 'http_${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
