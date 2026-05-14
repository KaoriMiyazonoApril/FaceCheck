import 'package:facecheck_app/features/face/face_photo_repository.dart';

class FacePhotoActions {
  static String statusTitle(FacePhotoSummary photo) {
    return switch (photo.status) {
      'ACTIVE' => 'Ready for recognition',
      'FAILED' => 'Needs re-upload',
      'DELETE_PENDING' => 'Deletion pending',
      'DELETE_FAILED' => 'Deletion failed',
      'DELETED' => 'Deleted',
      _ => 'Processing',
    };
  }

  static String statusMessage(FacePhotoSummary photo) {
    if (photo.failureReason != null && photo.failureReason!.trim().isNotEmpty) {
      return photo.failureReason!;
    }

    return switch (photo.status) {
      'ACTIVE' =>
        'This photo is active and can be used by future recognition flows.',
      'FAILED' =>
        'The backend rejected this photo during validation or registration.',
      'DELETE_PENDING' =>
        'Deletion is still being synchronized with external storage and FRS references.',
      'DELETE_FAILED' =>
        'Deletion synchronization failed and requires another attempt.',
      'DELETED' => 'This photo has already been removed.',
      _ =>
        'The photo has been accepted and is waiting for async detection or registration.',
    };
  }
}
