import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminManagedUser {
  const AdminManagedUser({
    required this.userId,
    required this.username,
    required this.role,
    required this.status,
  });

  final String userId;
  final String username;
  final String role;
  final String status;

  factory AdminManagedUser.fromJson(Object? json) {
    final payload = _asMap(json);
    return AdminManagedUser(
      userId: payload['userId']?.toString() ?? '',
      username: payload['username']?.toString() ?? '',
      role: payload['role']?.toString() ?? 'USER',
      status: payload['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class AdminSessionSummary {
  const AdminSessionSummary({
    required this.sessionId,
    required this.name,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.lateAfterTime,
    required this.status,
    required this.qrTokenVersion,
    required this.createdAt,
  });

  final String sessionId;
  final String name;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? lateAfterTime;
  final String status;
  final int qrTokenVersion;
  final DateTime createdAt;

  factory AdminSessionSummary.fromJson(Object? json) {
    final payload = _asMap(json);
    return AdminSessionSummary(
      sessionId: payload['sessionId']?.toString() ?? '',
      name: payload['name']?.toString() ?? '',
      description: payload['description']?.toString() ?? '',
      startTime: _parseDateTime(payload['startTime']) ?? DateTime.now().toUtc(),
      endTime: _parseDateTime(payload['endTime']) ?? DateTime.now().toUtc(),
      lateAfterTime: _parseDateTime(payload['lateAfterTime']),
      status: payload['status']?.toString() ?? 'DRAFT',
      qrTokenVersion: (payload['qrTokenVersion'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(payload['createdAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class SessionQrToken {
  const SessionQrToken({
    required this.sessionId,
    required this.qrToken,
    required this.qrContent,
  });

  final String sessionId;
  final String qrToken;
  final String qrContent;

  factory SessionQrToken.fromJson(Object? json) {
    final payload = _asMap(json);
    return SessionQrToken(
      sessionId: payload['sessionId']?.toString() ?? '',
      qrToken: payload['qrToken']?.toString() ?? '',
      qrContent: payload['qrContent']?.toString() ?? '',
    );
  }
}

class AdminAttendanceRecord {
  const AdminAttendanceRecord({
    required this.recordId,
    required this.sessionId,
    required this.sessionName,
    required this.userId,
    required this.maskedUsername,
    required this.checkinTime,
    required this.status,
    required this.similarity,
  });

  final String recordId;
  final String sessionId;
  final String sessionName;
  final String userId;
  final String maskedUsername;
  final DateTime checkinTime;
  final String status;
  final double? similarity;

  factory AdminAttendanceRecord.fromJson(Object? json) {
    final payload = _asMap(json);
    return AdminAttendanceRecord(
      recordId: payload['recordId']?.toString() ?? '',
      sessionId: payload['sessionId']?.toString() ?? '',
      sessionName: payload['sessionName']?.toString() ?? '',
      userId: payload['userId']?.toString() ?? '',
      maskedUsername: payload['maskedUsername']?.toString() ?? '',
      checkinTime:
          _parseDateTime(payload['checkinTime']) ?? DateTime.now().toUtc(),
      status: payload['status']?.toString() ?? 'VALID',
      similarity: (payload['similarity'] as num?)?.toDouble(),
    );
  }
}

class AdminCheckinAttempt {
  const AdminCheckinAttempt({
    required this.attemptId,
    required this.sessionId,
    required this.sessionName,
    required this.status,
    required this.resultCode,
    required this.resultMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.matchedUserId,
    required this.maskedUsername,
    required this.similarity,
    required this.reviewed,
    required this.reviewNote,
    required this.reviewedAt,
    required this.reviewedByUserId,
    required this.retryCount,
  });

  final String attemptId;
  final String sessionId;
  final String sessionName;
  final String status;
  final String resultCode;
  final String resultMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? matchedUserId;
  final String? maskedUsername;
  final double? similarity;
  final bool reviewed;
  final String reviewNote;
  final DateTime? reviewedAt;
  final String? reviewedByUserId;
  final int retryCount;

  factory AdminCheckinAttempt.fromJson(Object? json) {
    final payload = _asMap(json);
    return AdminCheckinAttempt(
      attemptId: payload['attemptId']?.toString() ?? '',
      sessionId: payload['sessionId']?.toString() ?? '',
      sessionName: payload['sessionName']?.toString() ?? '',
      status: payload['status']?.toString() ?? 'FAILED',
      resultCode: payload['resultCode']?.toString() ?? '',
      resultMessage: payload['resultMessage']?.toString() ?? '',
      createdAt: _parseDateTime(payload['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(payload['updatedAt']) ?? DateTime.now().toUtc(),
      matchedUserId: payload['matchedUserId']?.toString(),
      maskedUsername: payload['maskedUsername']?.toString(),
      similarity: (payload['similarity'] as num?)?.toDouble(),
      reviewed: payload['reviewed'] == true,
      reviewNote: payload['reviewNote']?.toString() ?? '',
      reviewedAt: _parseDateTime(payload['reviewedAt']),
      reviewedByUserId: payload['reviewedByUserId']?.toString(),
      retryCount: (payload['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SystemStateSummary {
  const SystemStateSummary({
    required this.database,
    required this.redis,
    required this.rabbitmq,
    required this.frs,
    required this.obs,
    required this.checkedAt,
  });

  final String database;
  final String redis;
  final String rabbitmq;
  final String frs;
  final String obs;
  final DateTime checkedAt;

  factory SystemStateSummary.fromJson(Object? json) {
    final payload = _asMap(json);
    return SystemStateSummary(
      database: payload['database']?.toString() ?? '',
      redis: payload['redis']?.toString() ?? '',
      rabbitmq: payload['rabbitmq']?.toString() ?? '',
      frs: payload['frs']?.toString() ?? '',
      obs: payload['obs']?.toString() ?? '',
      checkedAt: _parseDateTime(payload['checkedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class SystemConfigItem {
  const SystemConfigItem({
    required this.configKey,
    required this.configValue,
    required this.valueType,
    required this.description,
    required this.updatedAt,
  });

  final String configKey;
  final String configValue;
  final String valueType;
  final String description;
  final DateTime updatedAt;

  factory SystemConfigItem.fromJson(Object? json) {
    final payload = _asMap(json);
    return SystemConfigItem(
      configKey: payload['configKey']?.toString() ?? '',
      configValue: payload['configValue']?.toString() ?? '',
      valueType: payload['valueType']?.toString() ?? 'STRING',
      description: payload['description']?.toString() ?? '',
      updatedAt: _parseDateTime(payload['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AdminManagedUser>> fetchUsers() {
    return _apiClient.getEnvelope<List<AdminManagedUser>>(
      '/api/admin/users',
      decoder: (Object? json) => _decodeList(json, AdminManagedUser.fromJson),
    );
  }

  Future<AdminManagedUser> createUser({
    required String username,
    required String password,
    required String role,
  }) {
    return _apiClient.postEnvelope<AdminManagedUser>(
      '/api/admin/users',
      data: <String, Object>{
        'username': username.trim(),
        'password': password,
        'role': role,
      },
      decoder: AdminManagedUser.fromJson,
    );
  }

  Future<AdminManagedUser> updateUser({
    required String userId,
    required String username,
    String? password,
    required String role,
    required String status,
  }) {
    final body = <String, Object>{
      'username': username.trim(),
      'role': role,
      'status': status,
    };
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password;
    }
    return _apiClient.putEnvelope<AdminManagedUser>(
      '/api/admin/users/$userId',
      data: body,
      decoder: AdminManagedUser.fromJson,
    );
  }

  Future<AdminManagedUser> disableUser(String userId) {
    return _apiClient.postEnvelope<AdminManagedUser>(
      '/api/admin/users/$userId/disable',
      decoder: AdminManagedUser.fromJson,
    );
  }

  Future<List<AdminSessionSummary>> fetchSessions() {
    return _apiClient.getEnvelope<List<AdminSessionSummary>>(
      '/api/admin/sessions',
      decoder: (Object? json) =>
          _decodeList(json, AdminSessionSummary.fromJson),
    );
  }

  Future<AdminSessionSummary> createSession({
    required String name,
    required String description,
    required String startTime,
    required String endTime,
    String? lateAfterTime,
  }) {
    return _apiClient.postEnvelope<AdminSessionSummary>(
      '/api/admin/sessions',
      data: <String, Object?>{
        'name': name.trim(),
        'description': description.trim(),
        'startTime': startTime,
        'endTime': endTime,
        'lateAfterTime': lateAfterTime,
      },
      decoder: AdminSessionSummary.fromJson,
    );
  }

  Future<AdminSessionSummary> updateSession({
    required String sessionId,
    required String name,
    required String description,
    required String startTime,
    required String endTime,
    String? lateAfterTime,
  }) {
    return _apiClient.putEnvelope<AdminSessionSummary>(
      '/api/admin/sessions/$sessionId',
      data: <String, Object?>{
        'name': name.trim(),
        'description': description.trim(),
        'startTime': startTime,
        'endTime': endTime,
        'lateAfterTime': lateAfterTime,
      },
      decoder: AdminSessionSummary.fromJson,
    );
  }

  Future<AdminSessionSummary> publishSession(String sessionId) {
    return _apiClient.postEnvelope<AdminSessionSummary>(
      '/api/admin/sessions/$sessionId/publish',
      decoder: AdminSessionSummary.fromJson,
    );
  }

  Future<AdminSessionSummary> closeSession(String sessionId) {
    return _apiClient.postEnvelope<AdminSessionSummary>(
      '/api/admin/sessions/$sessionId/close',
      decoder: AdminSessionSummary.fromJson,
    );
  }

  Future<AdminSessionSummary> cancelSession(String sessionId) {
    return _apiClient.postEnvelope<AdminSessionSummary>(
      '/api/admin/sessions/$sessionId/cancel',
      decoder: AdminSessionSummary.fromJson,
    );
  }

  Future<SessionQrToken> fetchQrToken(String sessionId) {
    return _apiClient.getEnvelope<SessionQrToken>(
      '/api/admin/sessions/$sessionId/qr-token',
      decoder: SessionQrToken.fromJson,
    );
  }

  Future<SessionQrToken> resetQrToken(String sessionId) {
    return _apiClient.postEnvelope<SessionQrToken>(
      '/api/admin/sessions/$sessionId/qr-token/reset',
      decoder: SessionQrToken.fromJson,
    );
  }

  Future<List<AdminAttendanceRecord>> fetchGlobalRecords({
    String? sessionId,
    String? userId,
    String? status,
  }) {
    return _apiClient.getEnvelope<List<AdminAttendanceRecord>>(
      '/api/admin/attendance-records',
      queryParameters: <String, dynamic>{
        if (_hasValue(sessionId)) 'sessionId': sessionId,
        if (_hasValue(userId)) 'userId': userId,
        if (_hasValue(status)) 'status': status,
      },
      decoder: (Object? json) =>
          _decodeList(json, AdminAttendanceRecord.fromJson),
    );
  }

  Future<List<AdminAttendanceRecord>> fetchSessionRecords(
    String sessionId, {
    String? status,
  }) {
    return _apiClient.getEnvelope<List<AdminAttendanceRecord>>(
      '/api/admin/sessions/$sessionId/records',
      queryParameters: <String, dynamic>{
        if (_hasValue(status)) 'status': status,
      },
      decoder: (Object? json) =>
          _decodeList(json, AdminAttendanceRecord.fromJson),
    );
  }

  Future<List<AdminCheckinAttempt>> fetchAttempts({
    String? status,
    String? resultCode,
    String? sessionId,
    bool? reviewed,
  }) {
    return _apiClient.getEnvelope<List<AdminCheckinAttempt>>(
      '/api/admin/checkin-attempts',
      queryParameters: <String, dynamic>{
        if (_hasValue(status)) 'status': status,
        if (_hasValue(resultCode)) 'resultCode': resultCode,
        if (_hasValue(sessionId)) 'sessionId': sessionId,
        if (reviewed != null) 'reviewed': reviewed,
      },
      decoder: (Object? json) =>
          _decodeList(json, AdminCheckinAttempt.fromJson),
    );
  }

  Future<AdminCheckinAttempt> reviewAttempt({
    required String attemptId,
    required String note,
    required bool reviewed,
  }) {
    return _apiClient.postEnvelope<AdminCheckinAttempt>(
      '/api/admin/checkin-attempts/$attemptId/review',
      data: <String, Object?>{
        'note': note,
        'reviewed': reviewed,
      },
      decoder: AdminCheckinAttempt.fromJson,
    );
  }

  Future<AdminCheckinAttempt> retryAttempt(String attemptId) {
    return _apiClient.postEnvelope<AdminCheckinAttempt>(
      '/api/admin/checkin-attempts/$attemptId/retry',
      decoder: AdminCheckinAttempt.fromJson,
    );
  }

  Future<SystemStateSummary> fetchSystemState() {
    return _apiClient.getEnvelope<SystemStateSummary>(
      '/api/admin/system/state',
      decoder: SystemStateSummary.fromJson,
    );
  }

  Future<List<SystemConfigItem>> fetchSystemConfigs() {
    return _apiClient.getEnvelope<List<SystemConfigItem>>(
      '/api/admin/system/config',
      decoder: (Object? json) => _decodeList(json, SystemConfigItem.fromJson),
    );
  }

  Future<SystemConfigItem> updateSystemConfig({
    required String configKey,
    required String configValue,
  }) {
    return _apiClient.putEnvelope<SystemConfigItem>(
      '/api/admin/system/config/$configKey',
      data: <String, Object>{
        'configValue': configValue,
      },
      decoder: SystemConfigItem.fromJson,
    );
  }

  static List<T> _decodeList<T>(
    Object? json,
    T Function(Object? item) decoder,
  ) {
    if (json is List) {
      return json.map<T>(decoder).toList();
    }
    return <T>[];
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (Ref ref) => AdminRepository(ref.watch(apiClientProvider)),
);

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? innerValue) => MapEntry(
        key.toString(),
        innerValue,
      ),
    );
  }
  return const <String, dynamic>{};
}

DateTime? _parseDateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
