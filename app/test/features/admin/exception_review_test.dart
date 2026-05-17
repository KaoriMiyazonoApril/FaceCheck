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
  testWidgets('admin exception review page supports review and retry actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeAdminRepository();

    await _pumpAdminRouter(
      tester,
      repository: repository,
      initialLocation: AppRoutePaths.adminReview,
    );

    expect(find.byKey(AppTestKeys.adminExceptionReviewPage), findsOneWidget);
    expect(find.textContaining('MANUAL_REVIEW'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '复核').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '需要人工确认');
    await tester.tap(find.text('标记为已复核'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repository.reviewNotes.single, '需要人工确认');
    expect(find.text('复核备注：需要人工确认'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(repository.retryAttemptIds.single, 'attempt-1');
    expect(find.text('重试次数：1'), findsOneWidget);
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

  final List<String> reviewNotes = <String>[];
  final List<String> retryAttemptIds = <String>[];
  AdminCheckinAttempt attempt = AdminCheckinAttempt(
    attemptId: 'attempt-1',
    sessionId: 'session-1',
    sessionName: '晨检场次',
    status: 'FAILED',
    resultCode: 'MANUAL_REVIEW',
    resultMessage: '需要人工复核',
    createdAt: DateTime.utc(2026, 5, 16, 9, 10),
    updatedAt: DateTime.utc(2026, 5, 16, 9, 10),
    matchedUserId: null,
    maskedUsername: null,
    similarity: null,
    reviewed: false,
    reviewNote: '',
    reviewedAt: null,
    reviewedByUserId: null,
    retryCount: 0,
  );

  @override
  Future<List<AdminCheckinAttempt>> fetchAttempts({
    String? status,
    String? resultCode,
    String? sessionId,
    bool? reviewed,
  }) async {
    return <AdminCheckinAttempt>[attempt];
  }

  @override
  Future<AdminCheckinAttempt> reviewAttempt({
    required String attemptId,
    required String note,
    required bool reviewed,
  }) async {
    reviewNotes.add(note);
    attempt = AdminCheckinAttempt(
      attemptId: attempt.attemptId,
      sessionId: attempt.sessionId,
      sessionName: attempt.sessionName,
      status: attempt.status,
      resultCode: attempt.resultCode,
      resultMessage: attempt.resultMessage,
      createdAt: attempt.createdAt,
      updatedAt: attempt.updatedAt,
      matchedUserId: attempt.matchedUserId,
      maskedUsername: attempt.maskedUsername,
      similarity: attempt.similarity,
      reviewed: reviewed,
      reviewNote: note,
      reviewedAt: DateTime.utc(2026, 5, 16, 9, 20),
      reviewedByUserId: 'admin-1',
      retryCount: attempt.retryCount,
    );
    return attempt;
  }

  @override
  Future<AdminCheckinAttempt> retryAttempt(String attemptId) async {
    retryAttemptIds.add(attemptId);
    attempt = AdminCheckinAttempt(
      attemptId: attempt.attemptId,
      sessionId: attempt.sessionId,
      sessionName: attempt.sessionName,
      status: 'DUPLICATE_CHECKIN',
      resultCode: 'DUPLICATE_CHECKIN',
      resultMessage: '已完成签到',
      createdAt: attempt.createdAt,
      updatedAt: DateTime.utc(2026, 5, 16, 9, 30),
      matchedUserId: 'user-1',
      maskedUsername: '张*三',
      similarity: 95.0,
      reviewed: true,
      reviewNote: attempt.reviewNote,
      reviewedAt: DateTime.utc(2026, 5, 16, 9, 20),
      reviewedByUserId: 'admin-1',
      retryCount: 1,
    );
    return attempt;
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(readAccessToken: () async => null),
  );
}
