import 'package:facecheck_app/features/records/personal_records_controller.dart';
import 'package:facecheck_app/features/records/personal_records_page.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('personal records page shows only self history fields', (
    WidgetTester tester,
  ) async {
    final repository = _FakePersonalRecordsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          personalRecordsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: PersonalRecordsPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Morning Roll Call'), findsOneWidget);
    expect(find.text('Check-in completed successfully.'), findsOneWidget);
    expect(find.text('VALID'), findsOneWidget);
    expect(find.textContaining('userId'), findsNothing);
    expect(find.textContaining('maskedUsername'), findsNothing);
  });
}

class _FakePersonalRecordsRepository extends PersonalRecordsRepository {
  _FakePersonalRecordsRepository() : super(_dummyApiClient());

  @override
  Future<List<PersonalAttendanceRecord>> fetchRecords({
    DateTime? from,
    DateTime? to,
  }) async {
    return <PersonalAttendanceRecord>[
      PersonalAttendanceRecord(
        recordId: 'record-1',
        sessionId: 'session-1',
        sessionName: 'Morning Roll Call',
        checkinTime: DateTime.utc(2026, 5, 11, 8, 30),
        status: 'VALID',
        message: 'Check-in completed successfully.',
      ),
    ];
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
