import 'package:facecheck_app/features/auth/auth_state_notifier.dart';
import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/features/profile/profile_controller.dart';
import 'package:facecheck_app/features/profile/profile_page.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/app_role.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile page loads and updates username/password only', (
    WidgetTester tester,
  ) async {
    final repository = _FakeProfileRepository();
    final authNotifier = _StaticAuthStateNotifier(
      AuthState(session: _session()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          profileRepositoryProvider.overrideWithValue(repository),
          authStateNotifierProvider.overrideWith((Ref ref) => authNotifier),
          secureKeyValueStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(AppTestKeys.userProfilePage), findsOneWidget);
    expect(find.text('账户设置'), findsOneWidget);
    expect(find.text('角色：用户'), findsOneWidget);
    expect(find.text('状态：启用'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('新密码'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'renamed-user');
    await tester.enterText(find.byType(TextField).last, 'new-password');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedUsername, 'renamed-user');
    expect(repository.updatedPassword, 'new-password');
    expect(find.text('个人资料已更新。'), findsOneWidget);
    expect(authNotifier.state.session?.username, 'renamed-user');
  });
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(_dummyApiClient());

  String? updatedUsername;
  String? updatedPassword;

  @override
  Future<UserProfile> fetchProfile() async {
    return const UserProfile(
      userId: 'user-1',
      username: 'alice',
      role: 'USER',
      status: 'ACTIVE',
    );
  }

  @override
  Future<UserProfile> updateProfile({
    required String username,
    required String password,
  }) async {
    updatedUsername = username;
    updatedPassword = password;
    return UserProfile(
      userId: 'user-1',
      username: username,
      role: 'USER',
      status: 'ACTIVE',
    );
  }
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

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: 'user-1',
    username: 'alice',
    role: AppRole.user,
  );
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(
      readAccessToken: () async => null,
    ),
  );
}
