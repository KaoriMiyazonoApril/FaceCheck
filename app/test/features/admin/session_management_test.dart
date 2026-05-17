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
  testWidgets(
      'admin session management supports create edit publish and qr view',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeAdminRepository(
      sessions: <AdminSessionSummary>[
        AdminSessionSummary(
          sessionId: 'session-1',
          name: '晨检场次',
          description: '教学楼大厅',
          startTime: DateTime.utc(2026, 5, 16, 9),
          endTime: DateTime.utc(2026, 5, 16, 10),
          lateAfterTime: null,
          status: 'DRAFT',
          qrTokenVersion: 1,
          createdAt: DateTime.utc(2026, 5, 16, 8, 30),
        ),
      ],
    );

    await _pumpAdminRouter(
      tester,
      repository: repository,
      initialLocation: AppRoutePaths.adminSessions,
    );

    expect(find.byKey(AppTestKeys.adminSessionListPage), findsOneWidget);
    expect(find.text('晨检场次'), findsOneWidget);

    await tester.tap(find.byKey(AppTestKeys.adminCreateSessionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppTestKeys.adminSessionFormPage), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '晚检场次');
    await tester.enterText(find.byType(TextField).at(1), '宿舍区门口');
    await tester.enterText(
        find.byType(TextField).at(2), '2026-05-16T18:00:00Z');
    await tester.enterText(
        find.byType(TextField).at(3), '2026-05-16T19:00:00Z');
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();

    expect(repository.createdSessionNames.single, '晚检场次');
    expect(find.text('晚检场次'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '编辑').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '晨检场次（调整）');
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();

    expect(repository.updatedSessionNames.single, '晨检场次（调整）');
    expect(find.text('晨检场次（调整）'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '发布').first);
    await tester.pumpAndSettle();

    expect(repository.publishedSessionIds.single, 'session-1');
    expect(find.text('状态：已发布'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '查看二维码').first);
    await tester.pumpAndSettle();

    expect(find.byKey(AppTestKeys.adminSessionQrPage), findsOneWidget);
    expect(find.textContaining('facecheck://checkin/session-entry'),
        findsOneWidget);

    await tester.tap(find.text('重新生成二维码'));
    await tester.pumpAndSettle();

    expect(repository.resetQrSessionIds.single, 'session-1');
    expect(find.textContaining('qrToken=token-v2'), findsOneWidget);
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
    required List<AdminSessionSummary> sessions,
  })  : _sessions = List<AdminSessionSummary>.from(sessions),
        super(_dummyApiClient());

  final List<AdminSessionSummary> _sessions;
  final List<String> createdSessionNames = <String>[];
  final List<String> updatedSessionNames = <String>[];
  final List<String> publishedSessionIds = <String>[];
  final List<String> resetQrSessionIds = <String>[];

  @override
  Future<List<AdminSessionSummary>> fetchSessions() async {
    return List<AdminSessionSummary>.from(_sessions);
  }

  @override
  Future<AdminSessionSummary> createSession({
    required String name,
    required String description,
    required String startTime,
    required String endTime,
    String? lateAfterTime,
  }) async {
    createdSessionNames.add(name);
    final created = AdminSessionSummary(
      sessionId: 'session-${_sessions.length + 1}',
      name: name,
      description: description,
      startTime: DateTime.parse(startTime),
      endTime: DateTime.parse(endTime),
      lateAfterTime:
          lateAfterTime == null ? null : DateTime.parse(lateAfterTime),
      status: 'DRAFT',
      qrTokenVersion: 1,
      createdAt: DateTime.utc(2026, 5, 16, 8, 0),
    );
    _sessions.add(created);
    return created;
  }

  @override
  Future<AdminSessionSummary> updateSession({
    required String sessionId,
    required String name,
    required String description,
    required String startTime,
    required String endTime,
    String? lateAfterTime,
  }) async {
    final index = _sessions.indexWhere(
      (AdminSessionSummary session) => session.sessionId == sessionId,
    );
    final existing = _sessions[index];
    final updated = AdminSessionSummary(
      sessionId: sessionId,
      name: name,
      description: description,
      startTime: DateTime.parse(startTime),
      endTime: DateTime.parse(endTime),
      lateAfterTime:
          lateAfterTime == null ? null : DateTime.parse(lateAfterTime),
      status: existing.status,
      qrTokenVersion: existing.qrTokenVersion,
      createdAt: existing.createdAt,
    );
    updatedSessionNames.add(name);
    _sessions[index] = updated;
    return updated;
  }

  @override
  Future<AdminSessionSummary> publishSession(String sessionId) async {
    publishedSessionIds.add(sessionId);
    final index = _sessions.indexWhere(
      (AdminSessionSummary session) => session.sessionId == sessionId,
    );
    final existing = _sessions[index];
    final updated = AdminSessionSummary(
      sessionId: existing.sessionId,
      name: existing.name,
      description: existing.description,
      startTime: existing.startTime,
      endTime: existing.endTime,
      lateAfterTime: existing.lateAfterTime,
      status: 'PUBLISHED',
      qrTokenVersion: existing.qrTokenVersion,
      createdAt: existing.createdAt,
    );
    _sessions[index] = updated;
    return updated;
  }

  @override
  Future<SessionQrToken> fetchQrToken(String sessionId) async {
    return const SessionQrToken(
      sessionId: 'session-1',
      qrToken: 'token-v1',
      qrContent: 'facecheck://checkin/session-entry?qrToken=token-v1',
    );
  }

  @override
  Future<SessionQrToken> resetQrToken(String sessionId) async {
    resetQrSessionIds.add(sessionId);
    return const SessionQrToken(
      sessionId: 'session-1',
      qrToken: 'token-v2',
      qrContent: 'facecheck://checkin/session-entry?qrToken=token-v2',
    );
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(readAccessToken: () async => null),
  );
}
