import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/checkin_result_page.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result page maps duplicate check-ins without exposing private data', (
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

    expect(find.text('Already checked in'), findsOneWidget);
    expect(
      find.text(
        'This user has already completed check-in for the current session.',
      ),
      findsOneWidget,
    );
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
        expectedTitle: 'Session not started',
        expectedMessage:
            'The session has not opened yet. Wait for the start time and try again.',
      ),
      (
        attemptId: 'attempt-expired',
        resultCode: 'EXPIRED_SESSION',
        expectedTitle: 'Session expired',
        expectedMessage: 'The session is already past its closing time.',
      ),
      (
        attemptId: 'attempt-closed',
        resultCode: 'SESSION_CLOSED',
        expectedTitle: 'Session closed',
        expectedMessage: 'An administrator has already closed this session.',
      ),
      (
        attemptId: 'attempt-canceled',
        resultCode: 'SESSION_CANCELED',
        expectedTitle: 'Session canceled',
        expectedMessage:
            'This session was canceled and no longer accepts anonymous check-ins.',
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
        home: CheckinResultPage(attemptId: attemptId),
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
