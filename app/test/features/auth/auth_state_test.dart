import 'package:facecheck_app/features/auth/auth_state_notifier.dart';
import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/models/app_role.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthStateNotifier', () {
    test('restores a persisted session from secure storage', () async {
      final session = _session();
      final store = _MemoryStore();
      final storage = SecureStorageService(store);
      await storage.writeSession(session);

      final notifier = AuthStateNotifier(
        authApi: _FakeAuthApi(session),
        sessionRestoreService: SessionRestoreService(storage),
      );

      await notifier.restoreSession();

      expect(notifier.state.session?.username, 'alice');
      expect(notifier.state.session?.role, AppRole.user);
      expect(notifier.state.isRestoring, isFalse);
    });

    test('logout clears persisted session and local auth state', () async {
      final session = _session();
      final store = _MemoryStore();
      final storage = SecureStorageService(store);
      final api = _FakeAuthApi(session);
      final notifier = AuthStateNotifier(
        authApi: api,
        sessionRestoreService: SessionRestoreService(storage),
      );

      final loggedIn = await notifier.login(
        username: 'alice',
        password: 'secret',
      );

      expect(loggedIn, isTrue);
      expect((await storage.readSession())?.username, 'alice');

      await notifier.logout();

      expect(api.logoutCalled, isTrue);
      expect(await storage.readSession(), isNull);
      expect(notifier.state.session, isNull);
      expect(notifier.state.isSubmitting, isFalse);
    });
  });
}

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi(this._session);

  final AuthSession _session;
  bool logoutCalled = false;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    return _session;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
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
    userId: '8d2ad8f6-5f4f-4f2d-9134-b73377f31f9b',
    username: 'alice',
    role: AppRole.user,
  );
}
