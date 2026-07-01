import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/checkin_error_messages.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AnonymousCheckinState {
  const AnonymousCheckinState({
    this.photo,
    this.isPicking = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final SelectedPhoto? photo;
  final bool isPicking;
  final bool isSubmitting;
  final String? errorMessage;

  AnonymousCheckinState copyWith({
    SelectedPhoto? photo,
    bool clearPhoto = false,
    bool? isPicking,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnonymousCheckinState(
      photo: clearPhoto ? null : (photo ?? this.photo),
      isPicking: isPicking ?? this.isPicking,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AnonymousCheckinController extends StateNotifier<AnonymousCheckinState> {
  AnonymousCheckinController({
    required CheckinRepository repository,
    required FacePhotoCaptureService captureService,
  })  : _repository = repository,
        _captureService = captureService,
        super(const AnonymousCheckinState());

  final CheckinRepository _repository;
  final FacePhotoCaptureService _captureService;

  Future<void> pickPhoto(PhotoCaptureSource source) async {
    state = state.copyWith(
      isPicking: true,
      clearError: true,
    );

    try {
      final selectedPhoto = await _captureService.pickPhoto(source);
      state = state.copyWith(
        photo: selectedPhoto,
        isPicking: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isPicking: false,
        errorMessage: error is UnsupportedPhotoFormatException
            ? error.toString()
            : '无法读取所选照片，请重新选择。',
      );
    }
  }

  void clearPhoto() {
    state = state.copyWith(
      clearPhoto: true,
      clearError: true,
    );
  }

  Future<CheckinAttemptSummary?> submit({
    required String qrToken,
  }) async {
    final selectedPhoto = state.photo;
    if (selectedPhoto == null) {
      state = state.copyWith(
        errorMessage: '提交前请先拍摄或选择一张签到照片。',
      );
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final result = await _repository.submitCheckin(
        qrToken: qrToken,
        idempotencyKey: generateAnonymousIdempotencyKey(),
        photo: selectedPhoto,
        deviceId: _defaultDeviceId(),
      );
      state = state.copyWith(
        isSubmitting: false,
        clearError: true,
      );
      return result;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: anonymousSubmitErrorMessage(error),
      );
      return null;
    }
  }

  String _defaultDeviceId() {
    return 'flutter-${defaultTargetPlatform.name}';
  }
}

final anonymousCheckinControllerProvider = StateNotifierProvider.autoDispose<
    AnonymousCheckinController, AnonymousCheckinState>(
  (Ref ref) => AnonymousCheckinController(
    repository: ref.watch(checkinRepositoryProvider),
    captureService: ref.watch(facePhotoCaptureServiceProvider),
  ),
);
