import 'dart:async';

import 'package:facecheck_app/features/checkin/checkin_error_messages.dart';
import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class CheckinResultState {
  const CheckinResultState({
    this.attempt,
    this.isLoading = false,
    this.errorMessage,
  });

  final CheckinAttemptSummary? attempt;
  final bool isLoading;
  final String? errorMessage;

  CheckinResultState copyWith({
    CheckinAttemptSummary? attempt,
    bool clearAttempt = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckinResultState(
      attempt: clearAttempt ? null : (attempt ?? this.attempt),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CheckinResultController extends StateNotifier<CheckinResultState> {
  CheckinResultController({
    required CheckinRepository repository,
  })  : _repository = repository,
        super(const CheckinResultState());

  final CheckinRepository _repository;
  Timer? _pollTimer;
  String? _attemptId;
  String? _qrToken;

  Future<void> start({
    required String attemptId,
    required String qrToken,
    CheckinAttemptSummary? seedAttempt,
  }) async {
    _attemptId = attemptId;
    _qrToken = qrToken;
    _pollTimer?.cancel();

    if (seedAttempt != null) {
      state = state.copyWith(
        attempt: seedAttempt,
        isLoading: false,
        clearError: true,
      );
      if (seedAttempt.isProcessing) {
        _scheduleNextPoll(seedAttempt.nextPollAfterSeconds);
      }
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    final attemptId = _attemptId;
    final qrToken = _qrToken;
    if (attemptId == null ||
        attemptId.isEmpty ||
        qrToken == null ||
        qrToken.isEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final attempt = await _repository.fetchAttempt(
        attemptId: attemptId,
        qrToken: qrToken,
      );
      state = state.copyWith(
        attempt: attempt,
        isLoading: false,
        clearError: true,
      );
      if (attempt.isProcessing) {
        _scheduleNextPoll(attempt.nextPollAfterSeconds);
      } else {
        _pollTimer?.cancel();
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: checkinResultErrorMessage(error),
      );
    }
  }

  void _scheduleNextPoll(int? nextPollAfterSeconds) {
    _pollTimer?.cancel();
    final seconds = nextPollAfterSeconds == null || nextPollAfterSeconds <= 0
        ? 3
        : nextPollAfterSeconds;
    _pollTimer = Timer(Duration(seconds: seconds), refresh);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final checkinResultControllerProvider = StateNotifierProvider.autoDispose
    .family<CheckinResultController, CheckinResultState, CheckinResultLookup>(
  (Ref ref, CheckinResultLookup lookup) => CheckinResultController(
    repository: ref.watch(checkinRepositoryProvider),
  ),
);

@immutable
class CheckinResultLookup {
  const CheckinResultLookup({
    required this.attemptId,
    required this.qrToken,
  });

  final String attemptId;
  final String qrToken;

  @override
  bool operator ==(Object other) {
    return other is CheckinResultLookup &&
        other.attemptId == attemptId &&
        other.qrToken == qrToken;
  }

  @override
  int get hashCode => Object.hash(attemptId, qrToken);
}
