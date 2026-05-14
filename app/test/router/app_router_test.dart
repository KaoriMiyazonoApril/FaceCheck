import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/auth/auth_state_notifier.dart';
import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/qr_scan_page.dart';
import 'package:facecheck_app/router/app_router.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
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

  testWidgets('redirects malformed anonymous capture routes back to scan entry', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      state: const AuthState(),
      session: null,
      initialLocation: AppRoutePaths.publicCheckinCapture,
    );

    expect(find.text('Scan the FaceCheck session QR code'), findsOneWidget);
  });

  testWidgets('allows anonymous users to open result routes with attempt ids', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      state: const AuthState(),
      session: null,
      initialLocation:
          '${AppRoutePaths.publicCheckinResult}?attemptId=attempt-1',
      overrides: <Override>[
        checkinRepositoryProvider.overrideWithValue(
          _StaticCheckinRepository(
            const CheckinAttemptSummary(
              attemptId: 'attempt-1',
              sessionId: 'session-1',
              sessionName: 'Morning Roll Call',
              status: 'DUPLICATE_CHECKIN',
              resultCode: 'DUPLICATE_CHECKIN',
              resultMessage: '',
            ),
          ),
        ),
      ],
    );

    expect(find.text('Already checked in'), findsOneWidget);
  });
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required AuthState state,
  required AuthSession? session,
  required String initialLocation,
  List<Override> overrides = const <Override>[],
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
        qrScannerSurfaceBuilderProvider.overrideWithValue(
          (
            BuildContext context,
            void Function(String rawPayload) onScan,
          ) {
            return const SizedBox.shrink();
          },
        ),
        ...overrides,
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

class _StaticCheckinRepository extends CheckinRepository {
  _StaticCheckinRepository(this.attempt) : super(_dummyApiClient());

  final CheckinAttemptSummary attempt;

  @override
  Future<CheckinAttemptSummary> fetchAttempt(String attemptId) async {
    return attempt;
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(
      readAccessToken: () async => null,
    ),
  );
}
