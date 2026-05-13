import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';

class SessionRestoreService {
  SessionRestoreService(this._secureStorageService);

  final SecureStorageService _secureStorageService;

  Future<AuthSession?> restoreSession() {
    return _secureStorageService.readSession();
  }

  Future<void> persistSession(AuthSession session) {
    return _secureStorageService.writeSession(session);
  }

  Future<void> clearSession() {
    return _secureStorageService.clearSession();
  }
}
