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
  testWidgets('admin global records page supports filters', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAdminRepository();

    await _pumpAdminRouter(
      tester,
      repository: repository,
      initialLocation: AppRoutePaths.adminRecords,
    );

    expect(find.byKey(AppTestKeys.adminGlobalRecordsPage), findsOneWidget);
    expect(find.text('晨检场次'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'session-1');
    await tester.enterText(find.byType(TextField).at(1), 'user-1');
    await tester.tap(find.text('筛选记录'));
    await tester.pumpAndSettle();

    expect(repository.lastGlobalSessionId, 'session-1');
    expect(repository.lastGlobalUserId, 'user-1');
  });

  testWidgets('admin session records page loads session scoped records', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAdminRepository();

    await _pumpAdminRouter(
      tester,
      repository: repository,
      initialLocation: AppRoutePaths.adminSessionRecords(
        'session-1',
        sessionName: '晨检场次',
      ),
    );

    expect(find.byKey(AppTestKeys.adminSessionRecordsPage), findsOneWidget);
    expect(find.text('晨检场次'), findsOneWidget);
    expect(find.text('张*三'), findsOneWidget);

    await tester.tap(find.text('刷新场次记录'));
    await tester.pumpAndSettle();

    expect(repository.lastSessionRecordSessionId, 'session-1');
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
  _FakeAdminRepository() : super(_dummyApiClient());

  String? lastGlobalSessionId;
  String? lastGlobalUserId;
  String? lastSessionRecordSessionId;

  @override
  Future<List<AdminAttendanceRecord>> fetchGlobalRecords({
    String? sessionId,
    String? userId,
    String? status,
  }) async {
    lastGlobalSessionId = sessionId;
    lastGlobalUserId = userId;
    return <AdminAttendanceRecord>[
      AdminAttendanceRecord(
        recordId: 'record-1',
        sessionId: 'session-1',
        sessionName: '晨检场次',
        userId: 'user-1',
        maskedUsername: '张*三',
        checkinTime: DateTime.utc(2026, 5, 16, 9, 5),
        status: 'VALID',
        similarity: 95.0,
      ),
    ];
  }

  @override
  Future<List<AdminAttendanceRecord>> fetchSessionRecords(
    String sessionId, {
    String? status,
  }) async {
    lastSessionRecordSessionId = sessionId;
    return <AdminAttendanceRecord>[
      AdminAttendanceRecord(
        recordId: 'record-1',
        sessionId: sessionId,
        sessionName: '晨检场次',
        userId: 'user-1',
        maskedUsername: '张*三',
        checkinTime: DateTime.utc(2026, 5, 16, 9, 5),
        status: 'VALID',
        similarity: 95.0,
      ),
    ];
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(readAccessToken: () async => null),
  );
}
