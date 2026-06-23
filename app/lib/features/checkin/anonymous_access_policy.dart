import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';

class AnonymousAccessPolicy {
  static String? redirectFor(Uri uri, AuthSession? session) {
    final path = uri.path;

    if (path == AppRoutePaths.publicSessionConfirm &&
        !_hasAll(uri, <String>['qrToken'])) {
      return AppRoutePaths.publicSessionEntry;
    }

    if (path == AppRoutePaths.publicCheckinCapture &&
        !_hasAll(uri, <String>['qrToken', 'sessionName'])) {
      return AppRoutePaths.publicSessionEntry;
    }

    if (path == AppRoutePaths.publicCheckinResult &&
        !_hasAll(uri, <String>['attemptId', 'qrToken'])) {
      return AppRoutePaths.publicSessionEntry;
    }

    return null;
  }

  static bool _hasAll(Uri uri, List<String> keys) {
    for (final key in keys) {
      final value = uri.queryParameters[key];
      if (value == null || value.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}
