import 'dart:math';

import 'package:dio/dio.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

class CheckinAttemptSummary {
  const CheckinAttemptSummary({
    required this.attemptId,
    this.sessionId,
    required this.sessionName,
    required this.status,
    required this.resultCode,
    required this.resultMessage,
    this.checkinTime,
    this.maskedUsername,
    this.nextPollAfterSeconds,
  });

  final String attemptId;
  final String? sessionId;
  final String sessionName;
  final String status;
  final String resultCode;
  final String resultMessage;
  final DateTime? checkinTime;
  final String? maskedUsername;
  final int? nextPollAfterSeconds;

  bool get isProcessing => status == 'PROCESSING';
  bool get isFinal => !isProcessing;

  factory CheckinAttemptSummary.fromJson(Object? json) {
    final payload = json as Map<String, dynamic>;
    return CheckinAttemptSummary(
      attemptId: payload['attemptId']?.toString() ?? '',
      sessionId: payload['sessionId']?.toString(),
      sessionName: payload['sessionName']?.toString() ?? '',
      status: payload['status']?.toString() ?? '',
      resultCode: payload['resultCode']?.toString() ?? '',
      resultMessage: payload['resultMessage']?.toString() ?? '',
      checkinTime: DateTime.tryParse(payload['checkinTime']?.toString() ?? '')
          ?.toLocal(),
      maskedUsername: payload['maskedUsername']?.toString(),
      nextPollAfterSeconds: (payload['nextPollAfterSeconds'] as num?)?.toInt(),
    );
  }
}

class CheckinRepository {
  CheckinRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CheckinAttemptSummary> submitCheckin({
    required String qrToken,
    required String idempotencyKey,
    required SelectedPhoto photo,
    String? deviceId,
  }) {
    final formData = FormData.fromMap(
      <String, Object>{
        'qrToken': qrToken,
        'idempotencyKey': idempotencyKey,
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'deviceId': deviceId.trim(),
        'file': MultipartFile.fromBytes(
          photo.bytes,
          filename: photo.fileName,
          contentType: _contentTypeFor(photo.fileName),
        ),
      },
    );

    return _apiClient.postEnvelope<CheckinAttemptSummary>(
      '/api/public/checkin/attempts',
      data: formData,
      decoder: CheckinAttemptSummary.fromJson,
    );
  }

  Future<CheckinAttemptSummary> fetchAttempt({
    required String attemptId,
    required String qrToken,
  }) {
    return _apiClient.getEnvelope<CheckinAttemptSummary>(
      '/api/public/checkin/attempts/$attemptId',
      queryParameters: <String, dynamic>{
        'qrToken': qrToken,
      },
      decoder: CheckinAttemptSummary.fromJson,
    );
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

String generateAnonymousIdempotencyKey() {
  final random = Random.secure();
  final suffix = List<String>.generate(
    8,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return 'anon-${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

final checkinRepositoryProvider = Provider<CheckinRepository>(
  (Ref ref) => CheckinRepository(ref.watch(apiClientProvider)),
);
