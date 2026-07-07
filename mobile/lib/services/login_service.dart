import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/auth_repository.dart';
import '../data/gateways.dart';
import '../data/models/auth_user.dart';

/// Machine-readable sign-in failure; screens map these to localized text.
enum LoginError {
  invalidCredentials,
  emailAlreadyRegistered,
  network,
  googleUnavailable,
  unknown,
}

class LoginResult {
  const LoginResult({required this.success, this.user, this.error});

  final bool success;
  final AuthUser? user;
  final LoginError? error;

  factory LoginResult.ok(AuthUser user) =>
      LoginResult(success: true, user: user);

  factory LoginResult.failure(LoginError error) =>
      LoginResult(success: false, error: error);
}

class LoginService extends ChangeNotifier {
  LoginService(this._repository, this._gateway, this._profile, this._api);

  final AuthRepository _repository;
  final AuthGateway _gateway;
  final ProfileGateway _profile;
  final ApiClient _api;

  AuthUser? _currentUser;
  bool _loaded = false;
  bool _inProgress = false;

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoaded => _loaded;
  bool get isInProgress => _inProgress;

  Future<void> load() async {
    _currentUser = await _repository.loadUser();
    final token = await _repository.loadToken();
    if (_currentUser != null && token != null) {
      _api.token = token;
    } else {
      // A user without a token (or vice versa) is unusable half-state.
      _currentUser = null;
      _api.token = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<LoginResult> signInWithCredentials({
    required String email,
    required String password,
  }) {
    return _runSignIn(
      () => _gateway.signIn(email: email.trim(), password: password),
    );
  }

  Future<LoginResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? country,
  }) {
    return _runSignIn(
      () => _gateway.signUp(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        country: country,
      ),
    );
  }

  Future<LoginResult> signInWithGoogle() async {
    // The google_sign_in plugin isn't integrated yet; the backend endpoint
    // (/auth/google) exists and this becomes a real flow once it is.
    return LoginResult.failure(LoginError.googleUnavailable);
  }

  /// Updates the account's country on the server and in the local session.
  Future<bool> updateCountry(String country) async {
    if (_currentUser == null) return false;
    try {
      final updated = await _profile.updateProfile(country: country);
      _currentUser = updated;
      await _repository.saveUser(updated);
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<LoginResult> _runSignIn(
    Future<AuthSession> Function() performSignIn,
  ) async {
    _inProgress = true;
    notifyListeners();
    try {
      final session = await performSignIn();
      _currentUser = session.user;
      _api.token = session.token;
      await _repository.saveUser(session.user);
      await _repository.saveToken(session.token);
      return LoginResult.ok(session.user);
    } on ApiException catch (e) {
      return LoginResult.failure(_mapError(e));
    } finally {
      _inProgress = false;
      notifyListeners();
    }
  }

  static LoginError _mapError(ApiException e) {
    if (e.isNetwork) return LoginError.network;
    switch (e.code) {
      case 'invalid_credentials':
        return LoginError.invalidCredentials;
      case 'email_already_registered':
        return LoginError.emailAlreadyRegistered;
      default:
        return LoginError.unknown;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _api.token = null;
    await _repository.clear();
    notifyListeners();
  }
}
