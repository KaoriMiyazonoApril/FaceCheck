import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/checkin_result_page.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'result page maps duplicate check-ins without exposing private data', (
    WidgetTester tester,
  ) async {
    final repository = _StaticCheckinRepository(
      attempt: const CheckinAttemptSummary(
        attemptId: 'attempt-1',
        sessionId: 'session-1',
        sessionName: 'Morning Roll Call',
        status: 'DUPLICATE_CHECKIN',
        resultCode: 'DUPLICATE_CHECKIN',
        resultMessage: '',
      ),
    );

    await _pumpResultPage(tester, repository, 'attempt-1');

    expect(find.text('已完成签到'), findsOneWidget);
    expect(find.text('当前用户已经完成本场次签到。'), findsOneWidget);
    expect(find.textContaining('相似度'), findsNothing);
    expect(find.textContaining('userId'), findsNothing);
    expect(find.textContaining('username'), findsNothing);
  });

  testWidgets('result page maps session state failures to clear messages', (
    WidgetTester tester,
  ) async {
    final scenarios = <({
      String attemptId,
      String resultCode,
      String expectedTitle,
      String expectedMessage,
    })>[
      (
        attemptId: 'attempt-start',
        resultCode: 'SESSION_NOT_STARTED',
        expectedTitle: '场次未开始',
        expectedMessage: '该场次尚未开放，请到开始时间后再试。',
      ),
      (
        attemptId: 'attempt-expired',
        resultCode: 'EXPIRED_SESSION',
        expectedTitle: '场次已过期',
        expectedMessage: '该场次已经超过结束时间。',
      ),
      (
        attemptId: 'attempt-closed',
        resultCode: 'SESSION_CLOSED',
        expectedTitle: '场次已关闭',
        expectedMessage: '管理员已经关闭该场次。',
      ),
      (
        attemptId: 'attempt-canceled',
        resultCode: 'SESSION_CANCELED',
        expectedTitle: '场次已取消',
        expectedMessage: '该场次已被取消，不再接受匿名签到。',
      ),
    ];

    for (final scenario in scenarios) {
      final repository = _StaticCheckinRepository(
        attempt: CheckinAttemptSummary(
          attemptId: scenario.attemptId,
          sessionId: 'session-1',
          sessionName: 'Morning Roll Call',
          status: 'FAILED',
          resultCode: scenario.resultCode,
          resultMessage: '',
        ),
      );

      await _pumpResultPage(tester, repository, scenario.attemptId);

      expect(find.text(scenario.expectedTitle), findsOneWidget);
      expect(find.text(scenario.expectedMessage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _pumpResultPage(
  WidgetTester tester,
  CheckinRepository repository,
  String attemptId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        checkinRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: CheckinResultPage(attemptId: attemptId, qrToken: 'token-1'),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _StaticCheckinRepository extends CheckinRepository {
  _StaticCheckinRepository({
    required this.attempt,
  }) : super(_dummyApiClient());

  final CheckinAttemptSummary attempt;

  @override
  Future<CheckinAttemptSummary> fetchAttempt({
    required String attemptId,
    required String qrToken,
  }) async {
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
