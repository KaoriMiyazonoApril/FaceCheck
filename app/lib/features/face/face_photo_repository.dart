import 'package:dio/dio.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

class FacePhotoSummary {
  const FacePhotoSummary({
    required this.photoId,
    required this.userId,
    required this.status,
    required this.detectStatus,
    required this.registerStatus,
    required this.enabled,
    required this.createdAt,
    this.failureCode,
    this.failureReason,
    this.previewUrl,
  });

  final String photoId;
  final String userId;
  final String status;
  final String detectStatus;
  final String registerStatus;
  final String? failureCode;
  final String? failureReason;
  final String? previewUrl;
  final bool enabled;
  final DateTime createdAt;

  bool get isFailed => status == 'FAILED' || registerStatus == 'FAILED';

  factory FacePhotoSummary.fromJson(Object? json) {
    final payload = json as Map<String, dynamic>;
    return FacePhotoSummary(
      photoId: payload['photoId']?.toString() ?? '',
      userId: payload['userId']?.toString() ?? '',
      status: payload['status']?.toString() ?? '',
      detectStatus: payload['detectStatus']?.toString() ?? '',
      registerStatus: payload['registerStatus']?.toString() ?? '',
      failureCode: payload['failureCode']?.toString(),
      failureReason: payload['failureReason']?.toString(),
      previewUrl: payload['previewUrl']?.toString(),
      enabled: payload['enabled'] == true,
      createdAt: DateTime.tryParse(payload['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class FacePhotoRepository {
  FacePhotoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FacePhotoSummary>> fetchPhotos() {
    return _apiClient.getEnvelope<List<FacePhotoSummary>>(
      '/api/me/face-photos',
      decoder: (Object? json) {
        final list = json as List<Object?>? ?? const <Object?>[];
        return list.map(FacePhotoSummary.fromJson).toList();
      },
    );
  }

  Future<FacePhotoSummary> uploadPhoto(SelectedPhoto photo) {
    final formData = FormData.fromMap(
      <String, Object>{
        'file': MultipartFile.fromBytes(
          photo.bytes,
          filename: photo.fileName,
          contentType: _contentTypeFor(photo.fileName),
        ),
      },
    );

    return _apiClient.postEnvelope<FacePhotoSummary>(
      '/api/me/face-photos',
      data: formData,
      decoder: FacePhotoSummary.fromJson,
    );
  }

  Future<void> deletePhoto(String photoId) {
    return _apiClient.deleteNoContent('/api/me/face-photos/$photoId');
  }

  MediaType _contentTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'png'),
    };
  }
}

final facePhotoRepositoryProvider = Provider<FacePhotoRepository>(
  (Ref ref) => FacePhotoRepository(ref.watch(apiClientProvider)),
);
