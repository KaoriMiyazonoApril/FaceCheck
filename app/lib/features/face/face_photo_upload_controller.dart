import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/features/face/face_photo_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class FacePhotoUploadState {
  const FacePhotoUploadState({
    this.photos = const <FacePhotoSummary>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  static const int maxPhotos = 5;

  final List<FacePhotoSummary> photos;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  bool get isAtLimit => photos.length >= maxPhotos;
  int get remainingSlots => maxPhotos - photos.length;

  FacePhotoUploadState copyWith({
    List<FacePhotoSummary>? photos,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return FacePhotoUploadState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class FacePhotoUploadController extends StateNotifier<FacePhotoUploadState> {
  FacePhotoUploadController({
    required FacePhotoRepository repository,
    required FacePhotoCaptureService captureService,
  })  : _repository = repository,
        _captureService = captureService,
        super(const FacePhotoUploadState());

  final FacePhotoRepository _repository;
  final FacePhotoCaptureService _captureService;

  Future<void> loadPhotos() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final photos = await _repository.fetchPhotos();
      state = state.copyWith(
        photos: photos,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
        clearSuccess: true,
      );
    }
  }

  Future<void> uploadFromSource(PhotoCaptureSource source) {
    return _captureAndUpload(source: source);
  }

  Future<void> replacePhoto(
    String photoId,
    PhotoCaptureSource source,
  ) {
    return _captureAndUpload(source: source, replacePhotoId: photoId);
  }

  Future<void> deletePhoto(String photoId) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.deletePhoto(photoId);
      final photos = await _repository.fetchPhotos();
      state = state.copyWith(
        photos: photos,
        isSubmitting: false,
        successMessage: '照片已删除。',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
        clearSuccess: true,
      );
    }
  }

  Future<void> _captureAndUpload({
    required PhotoCaptureSource source,
    String? replacePhotoId,
  }) async {
    if (replacePhotoId == null && state.isAtLimit) {
      state = state.copyWith(
        errorMessage: '最多只能保留五张人脸照片。',
        clearSuccess: true,
      );
      return;
    }

    final selectedPhoto = await _captureService.pickPhoto(source);
    if (selectedPhoto == null) {
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      if (replacePhotoId != null) {
        await _repository.deletePhoto(replacePhotoId);
      }
      await _repository.uploadPhoto(selectedPhoto);
      final photos = await _repository.fetchPhotos();
      state = state.copyWith(
        photos: photos,
        isSubmitting: false,
        successMessage: replacePhotoId == null ? '照片已上传。' : '照片已替换。',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
        clearSuccess: true,
      );
    }
  }
}

final facePhotoUploadControllerProvider =
    StateNotifierProvider<FacePhotoUploadController, FacePhotoUploadState>(
  (Ref ref) => FacePhotoUploadController(
    repository: ref.watch(facePhotoRepositoryProvider),
    captureService: ref.watch(facePhotoCaptureServiceProvider),
  ),
);
