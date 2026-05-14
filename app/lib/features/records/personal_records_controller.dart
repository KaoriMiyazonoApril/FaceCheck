import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalAttendanceRecord {
  const PersonalAttendanceRecord({
    required this.recordId,
    required this.sessionId,
    required this.sessionName,
    required this.checkinTime,
    required this.status,
    required this.message,
  });

  final String recordId;
  final String sessionId;
  final String sessionName;
  final DateTime checkinTime;
  final String status;
  final String message;

  factory PersonalAttendanceRecord.fromJson(Object? json) {
    final payload = json as Map<String, dynamic>;
    return PersonalAttendanceRecord(
      recordId: payload['recordId']?.toString() ?? '',
      sessionId: payload['sessionId']?.toString() ?? '',
      sessionName: payload['sessionName']?.toString() ?? '',
      checkinTime:
          DateTime.tryParse(payload['checkinTime']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      status: payload['status']?.toString() ?? '',
      message: payload['message']?.toString() ?? '',
    );
  }
}

class PersonalRecordsRepository {
  PersonalRecordsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PersonalAttendanceRecord>> fetchRecords({
    DateTime? from,
    DateTime? to,
  }) {
    final query = <String, dynamic>{};
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    return _apiClient.getEnvelope<List<PersonalAttendanceRecord>>(
      '/api/me/attendance-records',
      queryParameters: query.isEmpty ? null : query,
      decoder: (Object? json) {
        final list = json as List<Object?>? ?? const <Object?>[];
        return list.map(PersonalAttendanceRecord.fromJson).toList();
      },
    );
  }
}

@immutable
class PersonalRecordsState {
  const PersonalRecordsState({
    this.records = const <PersonalAttendanceRecord>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<PersonalAttendanceRecord> records;
  final bool isLoading;
  final String? errorMessage;

  PersonalRecordsState copyWith({
    List<PersonalAttendanceRecord>? records,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PersonalRecordsState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PersonalRecordsController extends StateNotifier<PersonalRecordsState> {
  PersonalRecordsController({
    required PersonalRecordsRepository repository,
  })  : _repository = repository,
        super(const PersonalRecordsState());

  final PersonalRecordsRepository _repository;

  Future<void> loadRecords() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await _repository.fetchRecords();
      state = state.copyWith(
        records: records,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}

final personalRecordsRepositoryProvider = Provider<PersonalRecordsRepository>(
  (Ref ref) => PersonalRecordsRepository(ref.watch(apiClientProvider)),
);

final personalRecordsControllerProvider =
    StateNotifierProvider<PersonalRecordsController, PersonalRecordsState>(
  (Ref ref) => PersonalRecordsController(
    repository: ref.watch(personalRecordsRepositoryProvider),
  ),
);
