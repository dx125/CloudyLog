import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';

class LoginResult {
  const LoginResult({required this.success, this.user, this.errorMessage});

  final bool success;
  final AuthUser? user;
  final String? errorMessage;

  factory LoginResult.ok(AuthUser user) =>
      LoginResult(success: true, user: user);

  factory LoginResult.failure(String message) =>
      LoginResult(success: false, errorMessage: message);
}

class LoginService extends ChangeNotifier {
  LoginService(this._repository);

  final AuthRepository _repository;

  AuthUser? _currentUser;
  bool _loaded = false;
  bool _inProgress = false;

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoaded => _loaded;
  bool get isInProgress => _inProgress;

  Future<void> load() async {
    _currentUser = await _repository.loadUser();
    _loaded = true;
    notifyListeners();
  }

  Future<LoginResult> signInWithCredentials({
    required String username,
    required String password,
  }) async {
    return _runSignIn(() async {
      // TODO: replace with real backend auth call. Stub always succeeds.
      final user = AuthUser(
        id: 'local-${username.hashCode.toUnsigned(32)}',
        displayName: username,
        email: username.contains('@') ? username : '$username@local',
        provider: AuthProvider.credentials,
      );
      return LoginResult.ok(user);
    });
  }

  Future<LoginResult> signInWithGoogle() async {
    return _runSignIn(() async {
      // TODO: wire google_sign_in plugin. Stub always succeeds with a fake user.
      const user = AuthUser(
        id: 'google-stub-user',
        displayName: 'Google User',
        email: 'user@gmail.com',
        provider: AuthProvider.google,
      );
      return LoginResult.ok(user);
    });
  }

  Future<LoginResult> _runSignIn(
    Future<LoginResult> Function() performSignIn,
  ) async {
    _inProgress = true;
    notifyListeners();
    try {
      final result = await performSignIn();
      if (result.success && result.user != null) {
        _currentUser = result.user;
        await _repository.saveUser(result.user!);
      }
      return result;
    } finally {
      _inProgress = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _repository.clear();
    notifyListeners();
  }
}
