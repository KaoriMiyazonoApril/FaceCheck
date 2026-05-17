import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ExceptionReviewState {
  const ExceptionReviewState({
    this.attempts = const <AdminCheckinAttempt>[],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<AdminCheckinAttempt> attempts;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  ExceptionReviewState copyWith({
    List<AdminCheckinAttempt>? attempts,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExceptionReviewState(
      attempts: attempts ?? this.attempts,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExceptionReviewController extends StateNotifier<ExceptionReviewState> {
  ExceptionReviewController({
    required AdminRepository repository,
  })  : _repository = repository,
        super(const ExceptionReviewState());

  final AdminRepository _repository;

  Future<void> loadAttempts({
    String? status,
    String? resultCode,
    String? sessionId,
    bool? reviewed,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final attempts = await _repository.fetchAttempts(
        status: status,
        resultCode: resultCode,
        sessionId: sessionId,
        reviewed: reviewed,
      );
      state = state.copyWith(
        attempts: attempts,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _readableMessage(error),
      );
    }
  }

  Future<void> reviewAttempt({
    required String attemptId,
    required String note,
    required bool reviewed,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      final updated = await _repository.reviewAttempt(
        attemptId: attemptId,
        note: note,
        reviewed: reviewed,
      );
      state = state.copyWith(
        attempts: _replaceAttempt(updated),
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _readableMessage(error),
      );
    }
  }

  Future<void> retryAttempt(String attemptId) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      final updated = await _repository.retryAttempt(attemptId);
      state = state.copyWith(
        attempts: _replaceAttempt(updated),
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _readableMessage(error),
      );
    }
  }

  List<AdminCheckinAttempt> _replaceAttempt(AdminCheckinAttempt updated) {
    return state.attempts
        .map(
          (AdminCheckinAttempt attempt) =>
              attempt.attemptId == updated.attemptId ? updated : attempt,
        )
        .toList();
  }
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法处理复核动作，请稍后重试。';
}

final exceptionReviewControllerProvider =
    StateNotifierProvider<ExceptionReviewController, ExceptionReviewState>(
  (Ref ref) => ExceptionReviewController(
    repository: ref.watch(adminRepositoryProvider),
  ),
);
