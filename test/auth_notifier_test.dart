import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/models/user.dart';
import 'package:homeschooling/state/auth_providers.dart';
import 'package:homeschooling/state/environment.dart';
import 'package:mocktail/mocktail.dart';

import 'support/mock_repositories.dart';

const UserInfo _kUser = UserInfo(id: 'u1', email: 'a@b.com', fullName: 'A B');
const Membership _kMembership =
    Membership(familyId: 'f1', familyName: 'The Bs', guardianVerified: false, role: 'owner');

void main() {
  late TestEnvironment testEnv;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue('x');
  });

  setUp(() {
    testEnv = TestEnvironment();
    container = ProviderContainer(overrides: <Override>[environmentProvider.overrideWithValue(testEnv.build())]);
  });

  tearDown(() => container.dispose());

  test('with no stored session, restore lands on signedOut', () async {
    // The default (in-memory) TokenManager in TestEnvironment has no refresh token yet.
    container.read(authProvider); // triggers build()
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).status, AuthStatus.signedOut);
  });

  test('a successful login stores the session and exposes the user/memberships', () async {
    when(() => testEnv.auth.login(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
      (_) async => const AuthResult(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 900,
        user: _kUser,
        memberships: <Membership>[_kMembership],
      ),
    );

    final bool ok = await container.read(authProvider.notifier).login(email: 'a@b.com', password: 'password123');

    expect(ok, isTrue);
    final AuthState state = container.read(authProvider);
    expect(state.status, AuthStatus.signedIn);
    expect(state.user?.email, 'a@b.com');
    expect(state.family?.familyId, 'f1');
    expect(state.busy, isFalse);
  });

  test('a failed login keeps the user signed out and surfaces the error', () async {
    when(() => testEnv.auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const ServerException('unauthorized', '', status: 401));

    final bool ok = await container.read(authProvider.notifier).login(email: 'a@b.com', password: 'wrong');

    expect(ok, isFalse);
    final AuthState state = container.read(authProvider);
    expect(state.status, isNot(AuthStatus.signedIn));
    expect(state.error, isNotNull);
    expect(state.busy, isFalse);
  });

  test('logout clears the session even when the server call fails', () async {
    when(() => testEnv.auth.login(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
      (_) async => const AuthResult(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 900,
        user: _kUser,
        memberships: <Membership>[_kMembership],
      ),
    );
    await container.read(authProvider.notifier).login(email: 'a@b.com', password: 'password123');

    when(() => testEnv.auth.logout(any())).thenThrow(const NetworkException());
    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).status, AuthStatus.signedOut);
    expect(container.read(authProvider).user, isNull);
  });

  test('handleSessionExpired (triggered by a rejected refresh token) forces signedOut', () async {
    when(() => testEnv.auth.login(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
      (_) async => const AuthResult(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 900,
        user: _kUser,
        memberships: <Membership>[_kMembership],
      ),
    );
    await container.read(authProvider.notifier).login(email: 'a@b.com', password: 'password123');
    expect(container.read(authProvider).status, AuthStatus.signedIn);

    container.read(authProvider.notifier).handleSessionExpired();

    expect(container.read(authProvider).status, AuthStatus.signedOut);
  });
}
