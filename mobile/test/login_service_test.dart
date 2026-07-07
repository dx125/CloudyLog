import 'package:cloudy_log/data/api/api_client.dart';
import 'package:cloudy_log/data/models/auth_user.dart';
import 'package:cloudy_log/services/login_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('LoginService', () {
    late InMemoryAuthRepository repo;
    late FakeAuthGateway gateway;
    late FakeProfileGateway profile;
    late ApiClient api;
    late LoginService service;

    setUp(() async {
      repo = InMemoryAuthRepository();
      gateway = FakeAuthGateway();
      profile = FakeProfileGateway();
      api = ApiClient(baseUrl: 'http://unused');
      service = LoginService(repo, gateway, profile, api);
      await service.load();
    });

    test('starts logged out when nothing persisted', () {
      expect(service.isLoggedIn, isFalse);
      expect(service.currentUser, isNull);
      expect(api.hasToken, isFalse);
    });

    test('credentials sign-in persists user and token', () async {
      final result = await service.signInWithCredentials(
        email: 'a@b.c',
        password: 'secret',
      );
      expect(result.success, isTrue);
      expect(service.isLoggedIn, isTrue);
      expect(service.currentUser?.displayName, 'Alice');
      expect((await repo.loadUser())?.email, 'a@b.c');
      expect(await repo.loadToken(), 'token-1');
      expect(api.hasToken, isTrue);
    });

    test('sign-up forwards the country', () async {
      final result = await service.signUp(
        email: 'new@b.c',
        password: 'pw',
        displayName: 'New',
        country: 'UY',
      );
      expect(result.success, isTrue);
      expect(gateway.lastCountry, 'UY');
      expect(service.currentUser?.country, 'UY');
    });

    test('maps backend error codes', () async {
      gateway.failWith =
          const ApiException(code: 'invalid_credentials', statusCode: 401);
      final result = await service.signInWithCredentials(
        email: 'a@b.c',
        password: 'nope',
      );
      expect(result.success, isFalse);
      expect(result.error, LoginError.invalidCredentials);
      expect(service.isLoggedIn, isFalse);
    });

    test('maps network failures', () async {
      gateway.failWith = const ApiException.network();
      final result = await service.signInWithCredentials(
        email: 'a@b.c',
        password: 'pw',
      );
      expect(result.error, LoginError.network);
    });

    test('google sign-in reports unavailable', () async {
      final result = await service.signInWithGoogle();
      expect(result.success, isFalse);
      expect(result.error, LoginError.googleUnavailable);
    });

    test('signOut clears user, token and api client', () async {
      await service.signInWithCredentials(email: 'a@b.c', password: 'pw');
      await service.signOut();
      expect(service.isLoggedIn, isFalse);
      expect(await repo.loadUser(), isNull);
      expect(await repo.loadToken(), isNull);
      expect(api.hasToken, isFalse);
    });

    test('reload restores a persisted session', () async {
      await service.signInWithCredentials(email: 'a@b.c', password: 'pw');
      final freshApi = ApiClient(baseUrl: 'http://unused');
      final fresh = LoginService(repo, gateway, profile, freshApi);
      await fresh.load();
      expect(fresh.isLoggedIn, isTrue);
      expect(freshApi.hasToken, isTrue);
    });

    test('a persisted user without a token is discarded', () async {
      repo.user = const AuthUser(
        id: 'u9',
        displayName: 'Ghost',
        email: 'g@b.c',
        provider: AuthProvider.credentials,
      );
      final fresh = LoginService(repo, gateway, profile, api);
      await fresh.load();
      expect(fresh.isLoggedIn, isFalse);
    });

    test('updateCountry saves the new profile', () async {
      await service.signInWithCredentials(email: 'a@b.c', password: 'pw');
      final ok = await service.updateCountry('ES');
      expect(ok, isTrue);
      expect(profile.lastCountry, 'ES');
      expect(service.currentUser?.country, 'ES');
      expect((await repo.loadUser())?.country, 'ES');
    });
  });
}
