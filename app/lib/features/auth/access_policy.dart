import 'package:facecheck_app/shared/models/auth_session.dart';

class AppRoutePaths {
  static const String root = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/me/profile';
  static const String facePhotos = '/me/face-photos';
  static const String attendanceRecords = '/me/attendance-records';
  static const String publicSessionEntry = '/checkin/session-entry';
  static const String admin = '/admin';
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
