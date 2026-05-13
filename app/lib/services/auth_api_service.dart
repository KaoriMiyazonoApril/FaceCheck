import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';

abstract interface class AuthApi {
  Future<AuthSession> login({
    required String username,
    required String password,
  });

  Future<void> logout();
}

class DioAuthApiService implements AuthApi {
  DioAuthApiService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _apiClient.postEnvelope<AuthSession>(
      '/api/auth/login',
      data: <String, Object>{
        'username': username,
        'password': password,
      },
      decoder: AuthSession.fromLoginPayload,
    );
  }

  @override
  Future<void> logout() {
    return _apiClient.postNoContent('/api/auth/logout');
  }
}
