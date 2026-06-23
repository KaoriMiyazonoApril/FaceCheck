import 'dart:typed_data';

import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/qr_scan_page.dart';
import 'package:facecheck_app/features/checkin/session_entry_repository.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/router/app_router.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('anonymous users can move from scan to processing to success', (
    WidgetTester tester,
  ) async {
    final sessionRepository = _FakeSessionEntryRepository(
      sessions: <String, SessionEntryDetails>{
        'token-1': SessionEntryDetails(
          sessionId: 'session-1',
          name: 'Morning Roll Call',
          description: 'Main building lobby',
          startTime: DateTime(2026, 5, 14, 8, 0),
          endTime: DateTime(2026, 5, 14, 9, 0),
          status: 'PUBLISHED',
          canCheckin: true,
        ),
      },
    );
    final checkinRepository = _FakeCheckinRepository(
      submitResponse: const CheckinAttemptSummary(
        attemptId: 'attempt-1',
        sessionId: 'session-1',
        sessionName: 'Morning Roll Call',
        status: 'PROCESSING',
        resultCode: 'PROCESSING',
        resultMessage: '签到仍在处理中。',
        nextPollAfterSeconds: 3,
      ),
      fetchResponses: <CheckinAttemptSummary>[
        const CheckinAttemptSummary(
          attemptId: 'attempt-1',
          sessionId: 'session-1',
          sessionName: 'Morning Roll Call',
          status: 'PROCESSING',
          resultCode: 'PROCESSING',
          resultMessage: '签到仍在处理中。',
          nextPollAfterSeconds: 3,
        ),
        CheckinAttemptSummary(
          attemptId: 'attempt-1',
          sessionId: 'session-1',
          sessionName: 'Morning Roll Call',
          status: 'SUCCESS',
          resultCode: 'SUCCESS',
          resultMessage: '签到成功。',
          checkinTime: DateTime(2026, 5, 14, 8, 30),
          maskedUsername: 'u***r',
        ),
      ],
    );
    final captureService = _FakeCaptureService();

    await _pumpRouter(
      tester,
      initialLocation: AppRoutePaths.publicSessionEntry,
      overrides: <Override>[
        sessionEntryRepositoryProvider.overrideWithValue(sessionRepository),
        checkinRepositoryProvider.overrideWithValue(checkinRepository),
        facePhotoCaptureServiceProvider.overrideWithValue(captureService),
        qrScannerSurfaceBuilderProvider.overrideWithValue(
          (
            BuildContext context,
            void Function(String rawPayload) onScan,
          ) {
            return Center(
              child: FilledButton(
                onPressed: () => onScan(
                  'facecheck://checkin/session-entry?qrToken=token-1',
                ),
                child: const Text('模拟扫码'),
              ),
            );
          },
        ),
      ],
    );

    expect(find.byKey(AppTestKeys.anonymousCheckinEntryPage), findsOneWidget);
    expect(find.text('扫码签到'), findsOneWidget);

    await tester.tap(find.text('模拟扫码'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Roll Call'), findsOneWidget);
    expect(find.byKey(AppTestKeys.anonymousCheckinStartButton), findsOneWidget);

    await tester.tap(find.byKey(AppTestKeys.anonymousCheckinStartButton));
    await tester.pumpAndSettle();

    expect(find.text('拍摄签到照片'), findsOneWidget);

    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();

    expect(find.text('预览：selfie.png'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('提交匿名签到'),
      200,
    );
    await tester.tap(find.text('提交匿名签到'));
    await tester.pumpAndSettle();

    expect(find.text('仍在处理中'), findsOneWidget);
    expect(find.text('签到仍在处理中。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('签到成功'), findsOneWidget);
    expect(find.text('匹配用户：u***r'), findsOneWidget);
    expect(checkinRepository.submitCalls, 1);
    expect(checkinRepository.fetchCalls, 2);
  });

  testWidgets('direct qrToken routes show refusal reasons for closed sessions',
      (
    WidgetTester tester,
  ) async {
    final sessionRepository = _FakeSessionEntryRepository(
      sessions: <String, SessionEntryDetails>{
        'token-closed': SessionEntryDetails(
          sessionId: 'session-2',
          name: 'Closed Session',
          description: 'Old classroom',
          startTime: DateTime(2026, 5, 14, 8, 0),
          endTime: DateTime(2026, 5, 14, 9, 0),
          status: 'CLOSED',
          canCheckin: false,
          refusalCode: 'SESSION_CLOSED',
          refusalReason: '该场次已经关闭。',
        ),
      },
    );

    await _pumpRouter(
      tester,
      initialLocation:
          '${AppRoutePaths.publicSessionEntry}?qrToken=token-closed',
      overrides: <Override>[
        sessionEntryRepositoryProvider.overrideWithValue(sessionRepository),
        qrScannerSurfaceBuilderProvider.overrideWithValue(
          (
            BuildContext context,
            void Function(String rawPayload) onScan,
          ) {
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Closed Session'), findsOneWidget);
    expect(find.text('当前无法签到'), findsOneWidget);
    expect(find.text('该场次已经关闭。'), findsWidgets);
    expect(find.byKey(AppTestKeys.anonymousCheckinStartButton), findsNothing);
  });
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required String initialLocation,
  List<Override> overrides = const <Override>[],
}) async {
  final router = AppRouter.buildRouter(
    session: null,
    initialLocation: initialLocation,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeSessionEntryRepository extends SessionEntryRepository {
  _FakeSessionEntryRepository({
    required this.sessions,
  }) : super(_dummyApiClient());

  final Map<String, SessionEntryDetails> sessions;

  @override
  Future<SessionEntryDetails> resolveSession(String qrToken) async {
    return sessions[qrToken]!;
  }
}

class _FakeCheckinRepository extends CheckinRepository {
  _FakeCheckinRepository({
    required this.submitResponse,
    required List<CheckinAttemptSummary> fetchResponses,
  })  : _fetchResponses = List<CheckinAttemptSummary>.from(fetchResponses),
        super(_dummyApiClient());

  final CheckinAttemptSummary submitResponse;
  final List<CheckinAttemptSummary> _fetchResponses;
  int submitCalls = 0;
  int fetchCalls = 0;

  @override
  Future<CheckinAttemptSummary> submitCheckin({
    required String qrToken,
    required String idempotencyKey,
    required SelectedPhoto photo,
    String? deviceId,
  }) async {
    submitCalls += 1;
    return submitResponse;
  }

  @override
  Future<CheckinAttemptSummary> fetchAttempt({
    required String attemptId,
    required String qrToken,
  }) async {
    fetchCalls += 1;
    if (_fetchResponses.isEmpty) {
      return submitResponse;
    }
    return _fetchResponses.removeAt(0);
  }
}

class _FakeCaptureService implements FacePhotoCaptureService {
  @override
  Future<SelectedPhoto?> pickPhoto(PhotoCaptureSource source) async {
    return SelectedPhoto(
      fileName: 'selfie.png',
      bytes: Uint8List.fromList(_validPngBytes),
    );
  }
}

const List<int> _validPngBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(
      readAccessToken: () async => null,
    ),
  );
}
