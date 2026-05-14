import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/auth/auth_state_notifier.dart';
import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/router/app_router.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/models/app_role.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('redirects anonymous users away from signed-in routes', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      state: const AuthState(),
      session: null,
      initialLocation: AppRoutePaths.profile,
    );

    expect(find.text('FaceCheck Sign in'), findsOneWidget);
  });

  testWidgets('redirects anonymous users away from face photo routes', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      state: const AuthState(),
      session: null,
      initialLocation: AppRoutePaths.facePhotos,
    );

    expect(find.text('FaceCheck Sign in'), findsOneWidget);
  });

  testWidgets('redirects ordinary users away from admin routes', (
    WidgetTester tester,
  ) async {
    final session = _userSession();

    await _pumpRouter(
      tester,
      state: AuthState(session: session),
      session: session,
      initialLocation: AppRoutePaths.admin,
    );

    expect(find.text('Welcome back, alice'), findsOneWidget);
    expect(find.text('Admin Workspace'), findsNothing);
  });

  testWidgets('allows admins to open the admin route group', (
    WidgetTester tester,
  ) async {
    final session = _adminSession();

    await _pumpRouter(
      tester,
      state: AuthState(session: session),
      session: session,
      initialLocation: AppRoutePaths.admin,
    );

    expect(
      find.text(
        'Admin user, session, record, and review pages will be added in Stage 10.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required AuthState state,
  required AuthSession? session,
  required String initialLocation,
}) async {
  final notifier = _StaticAuthStateNotifier(state);
  final router = AppRouter.buildRouter(
    session: session,
    initialLocation: initialLocation,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authStateNotifierProvider.overrideWith((Ref ref) => notifier),
        secureKeyValueStoreProvider.overrideWithValue(_MemoryStore()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _StaticAuthStateNotifier extends AuthStateNotifier {
  _StaticAuthStateNotifier(AuthState initialState)
      : super(
          authApi: _NoopAuthApi(),
          sessionRestoreService: SessionRestoreService(
            SecureStorageService(_MemoryStore()),
          ),
        ) {
    state = initialState;
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return false;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession() async {}
}

class _NoopAuthApi implements AuthApi {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}

class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

AuthSession _userSession() {
  return const AuthSession(
    accessToken: 'user-token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: '1',
    username: 'alice',
    role: AppRole.user,
  );
}

AuthSession _adminSession() {
  return const AuthSession(
    accessToken: 'admin-token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: '2',
    username: 'admin',
    role: AppRole.admin,
  );
}
