import 'package:facecheck_app/shared/models/auth_session.dart';

class AppRoutePaths {
  static const String root = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/me/profile';
  static const String facePhotos = '/me/face-photos';
  static const String attendanceRecords = '/me/attendance-records';
  static const String publicSessionEntry = '/checkin/session-entry';
  static const String publicSessionConfirm = '/checkin/session-confirm';
  static const String publicCheckinCapture = '/checkin/capture';
  static const String publicCheckinResult = '/checkin/result';
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminUserCreate = '/admin/users/new';
  static const String adminUserEditPattern = '/admin/users/:userId/edit';
  static const String adminSessions = '/admin/sessions';
  static const String adminSessionCreate = '/admin/sessions/new';
  static const String adminSessionEditPattern =
      '/admin/sessions/:sessionId/edit';
  static const String adminSessionQrPattern = '/admin/sessions/:sessionId/qr';
  static const String adminSessionRecordsPattern =
      '/admin/sessions/:sessionId/records';
  static const String adminRecords = '/admin/records';
  static const String adminReview = '/admin/review';
  static const String adminSystemState = '/admin/system/state';
  static const String adminSystemConfig = '/admin/system/config';

  static String adminUserEdit(
    String userId, {
    String? username,
    String? role,
    String? status,
  }) {
    return Uri(
      path: '/admin/users/$userId/edit',
      queryParameters: <String, String>{
        if (username != null && username.isNotEmpty) 'username': username,
        if (role != null && role.isNotEmpty) 'role': role,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).toString();
  }

  static String adminSessionEdit(
    String sessionId, {
    String? name,
    String? description,
    String? startTime,
    String? endTime,
    String? lateAfterTime,
    String? status,
  }) {
    return Uri(
      path: '/admin/sessions/$sessionId/edit',
      queryParameters: <String, String>{
        if (name != null && name.isNotEmpty) 'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        if (lateAfterTime != null && lateAfterTime.isNotEmpty)
          'lateAfterTime': lateAfterTime,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).toString();
  }

  static String adminSessionQr(String sessionId, {String? sessionName}) {
    return Uri(
      path: '/admin/sessions/$sessionId/qr',
      queryParameters: <String, String>{
        if (sessionName != null && sessionName.isNotEmpty)
          'sessionName': sessionName,
      },
    ).toString();
  }

  static String adminSessionRecords(String sessionId, {String? sessionName}) {
    return Uri(
      path: '/admin/sessions/$sessionId/records',
      queryParameters: <String, String>{
        if (sessionName != null && sessionName.isNotEmpty)
          'sessionName': sessionName,
      },
    ).toString();
  }
}

class AccessPolicy {
  static String? redirectFor(String location, AuthSession? session) {
    if (location == AppRoutePaths.root) {
      return session == null ? AppRoutePaths.login : AppRoutePaths.home;
    }

    if (location == AppRoutePaths.login) {
      return session == null ? null : AppRoutePaths.home;
    }

    if (location.startsWith('/admin')) {
      if (session == null) {
        return AppRoutePaths.login;
      }
      if (!session.isAdmin) {
        return AppRoutePaths.home;
      }
      return null;
    }

    if (location == AppRoutePaths.home || location.startsWith('/me/')) {
      return session == null ? AppRoutePaths.login : null;
    }

    if (location.startsWith('/checkin/')) {
      return null;
    }

    return session == null ? AppRoutePaths.login : AppRoutePaths.home;
  }
}
