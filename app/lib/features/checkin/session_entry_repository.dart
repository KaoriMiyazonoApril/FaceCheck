import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionEntryDetails {
  const SessionEntryDetails({
    required this.sessionId,
    required this.name,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.canCheckin,
    this.refusalCode,
    this.refusalReason,
  });

  final String sessionId;
  final String name;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final bool canCheckin;
  final String? refusalCode;
  final String? refusalReason;

  factory SessionEntryDetails.fromJson(Object? json) {
    final payload = json as Map<String, dynamic>;
    return SessionEntryDetails(
      sessionId: payload['sessionId']?.toString() ?? '',
      name: payload['name']?.toString() ?? '',
      description: payload['description']?.toString(),
      startTime:
          DateTime.tryParse(payload['startTime']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          DateTime.tryParse(payload['endTime']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      status: payload['status']?.toString() ?? '',
      canCheckin: payload['canCheckin'] == true,
      refusalCode: payload['refusalCode']?.toString(),
      refusalReason: payload['refusalReason']?.toString(),
    );
  }
}

class SessionEntryRepository {
  SessionEntryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SessionEntryDetails> resolveSession(String qrToken) {
    return _apiClient.postEnvelope<SessionEntryDetails>(
      '/api/public/checkin/session-entry',
      data: <String, Object>{
        'qrToken': qrToken,
      },
      decoder: SessionEntryDetails.fromJson,
    );
  }
}

@immutable
class SessionEntryState {
  const SessionEntryState({
    this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  final SessionEntryDetails? session;
  final bool isLoading;
  final String? errorMessage;

  SessionEntryState copyWith({
    SessionEntryDetails? session,
    bool clearSession = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionEntryState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SessionEntryController extends StateNotifier<SessionEntryState> {
  SessionEntryController({
    required SessionEntryRepository repository,
  })  : _repository = repository,
        super(const SessionEntryState());

  final SessionEntryRepository _repository;

  Future<void> loadSession(String qrToken) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSession: true,
    );

    try {
      final session = await _repository.resolveSession(qrToken);
      state = state.copyWith(
        session: session,
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

final sessionEntryRepositoryProvider = Provider<SessionEntryRepository>(
  (Ref ref) => SessionEntryRepository(ref.watch(apiClientProvider)),
);

final sessionEntryControllerProvider = StateNotifierProvider.autoDispose
    .family<SessionEntryController, SessionEntryState, String>(
  (Ref ref, String qrToken) => SessionEntryController(
    repository: ref.watch(sessionEntryRepositoryProvider),
  ),
);
