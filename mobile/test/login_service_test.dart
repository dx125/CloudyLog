import 'package:cloudy_log/data/auth_repository.dart';
import 'package:cloudy_log/data/models/auth_user.dart';
import 'package:cloudy_log/services/login_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryAuthRepository implements AuthRepository {
  AuthUser? _user;

  @override
  Future<AuthUser?> loadUser() async => _user;

  @override
  Future<void> saveUser(AuthUser user) async {
    _user = user;
  }

  @override
  Future<void> clear() async {
    _user = null;
  }
}

void main() {
  group('LoginService', () {
    late _InMemoryAuthRepository repo;
    late LoginService service;

    setUp(() async {
      repo = _InMemoryAuthRepository();
      service = LoginService(repo);
      await service.load();
    });

    test('starts logged out when nothing persisted', () {
      expect(service.isLoggedIn, isFalse);
      expect(service.currentUser, isNull);
    });

    test('credentials sign-in stub succeeds and persists', () async {
      final result = await service.signInWithCredentials(
        username: 'alice',
        password: 'secret',
      );
      expect(result.success, isTrue);
      expect(service.isLoggedIn, isTrue);
      expect(service.currentUser?.displayName, 'alice');
      expect(service.currentUser?.provider, AuthProvider.credentials);
      expect((await repo.loadUser())?.displayName, 'alice');
    });

    test('google sign-in stub succeeds and persists', () async {
      final result = await service.signInWithGoogle();
      expect(result.success, isTrue);
      expect(service.currentUser?.provider, AuthProvider.google);
      expect(await repo.loadUser(), isNotNull);
    });

    test('signOut clears current user and storage', () async {
      await service.signInWithCredentials(username: 'bob', password: 'pw');
      await service.signOut();
      expect(service.isLoggedIn, isFalse);
      expect(await repo.loadUser(), isNull);
    });

    test('reload restores a persisted user', () async {
      await service.signInWithCredentials(username: 'carol', password: 'pw');
      final fresh = LoginService(repo);
      await fresh.load();
      expect(fresh.isLoggedIn, isTrue);
      expect(fresh.currentUser?.displayName, 'carol');
    });
  });
}
