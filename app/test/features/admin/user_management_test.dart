import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/router/app_router.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/app_role.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin user management supports create edit and disable flows', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAdminRepository(
      users: <AdminManagedUser>[
        const AdminManagedUser(
          userId: 'user-1',
          username: 'alice',
          role: 'USER',
          status: 'ACTIVE',
        ),
      ],
    );

    await _pumpAdminRouter(
      tester,
      repository: repository,
      initialLocation: AppRoutePaths.adminUsers,
    );

    expect(find.byKey(AppTestKeys.adminUserListPage), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('角色：普通用户'), findsOneWidget);

    await tester.tap(find.byKey(AppTestKeys.adminCreateUserButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppTestKeys.adminUserFormPage), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'new-admin');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.createdUsers.single.username, 'new-admin');
    expect(find.text('new-admin'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '编辑').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'renamed-admin');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedUsers.single.username, 'renamed-admin');
    expect(find.text('renamed-admin'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '停用').first);
    await tester.pumpAndSettle();

    expect(repository.disabledUserIds.single, 'generated-2');
    expect(find.text('状态：停用'), findsOneWidget);
  });
}

Future<void> _pumpAdminRouter(
  WidgetTester tester, {
  required _FakeAdminRepository repository,
  required String initialLocation,
}) async {
  final router = AppRouter.buildRouter(
    session: const AuthSession(
      accessToken: 'admin-token',
      tokenType: 'Bearer',
      expiresIn: 3600,
      userId: 'admin-1',
      username: 'admin',
      role: AppRole.admin,
    ),
    initialLocation: initialLocation,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository({
    required List<AdminManagedUser> users,
  })  : _users = List<AdminManagedUser>.from(users),
        super(_dummyApiClient());

  final List<AdminManagedUser> _users;
  final List<AdminManagedUser> createdUsers = <AdminManagedUser>[];
  final List<AdminManagedUser> updatedUsers = <AdminManagedUser>[];
  final List<String> disabledUserIds = <String>[];

  @override
  Future<List<AdminManagedUser>> fetchUsers() async {
    return List<AdminManagedUser>.from(_users);
  }

  @override
  Future<AdminManagedUser> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final created = AdminManagedUser(
      userId: 'generated-${_users.length + 1}',
      username: username,
      role: role,
      status: 'ACTIVE',
    );
    createdUsers.add(created);
    _users.insert(0, created);
    return created;
  }

  @override
  Future<AdminManagedUser> updateUser({
    required String userId,
    required String username,
    String? password,
    required String role,
    required String status,
  }) async {
    final index =
        _users.indexWhere((AdminManagedUser user) => user.userId == userId);
    final updated = AdminManagedUser(
      userId: userId,
      username: username,
      role: role,
      status: status,
    );
    _users[index] = updated;
    updatedUsers.add(updated);
    return updated;
  }

  @override
  Future<AdminManagedUser> disableUser(String userId) async {
    final index =
        _users.indexWhere((AdminManagedUser user) => user.userId == userId);
    final existing = _users[index];
    final disabled = AdminManagedUser(
      userId: existing.userId,
      username: existing.username,
      role: existing.role,
      status: 'DISABLED',
    );
    _users[index] = disabled;
    disabledUserIds.add(userId);
    return disabled;
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(readAccessToken: () async => null),
  );
}
