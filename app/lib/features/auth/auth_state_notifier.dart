import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AuthState {
  const AuthState({
    this.session,
    this.isRestoring = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthSession? session;
  final bool isRestoring;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AuthSession? session,
    bool clearSession = false,
    bool? isRestoring,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isRestoring: isRestoring ?? this.isRestoring,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier({
    required AuthApi authApi,
    required SessionRestoreService sessionRestoreService,
  })  : _authApi = authApi,
        _sessionRestoreService = sessionRestoreService,
        super(const AuthState());

  final AuthApi _authApi;
  final SessionRestoreService _sessionRestoreService;

  Future<void> restoreSession() async {
    if (state.isRestoring) {
      return;
    }

    state = state.copyWith(
      isRestoring: true,
      clearError: true,
    );

    try {
      final session = await _sessionRestoreService.restoreSession();
      state = state.copyWith(
        session: session,
        isRestoring: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isRestoring: false,
        clearError: true,
      );
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final session = await _authApi.login(
        username: username.trim(),
        password: password,
      );
      await _sessionRestoreService.persistSession(session);
      state = state.copyWith(
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      return true;
    } on BackendApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '当前无法登录，请稍后重试。',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      await _authApi.logout();
    } catch (_) {
      // Local session invalidation still needs to happen if logout fails.
    } finally {
      await _sessionRestoreService.clearSession();
      state = state.copyWith(
        clearSession: true,
        isSubmitting: false,
        clearError: true,
      );
    }
  }

  Future<void> replaceUsername(String username) async {
    final currentSession = state.session;
    if (currentSession == null) {
      return;
    }

    final updatedSession = AuthSession(
      accessToken: currentSession.accessToken,
      tokenType: currentSession.tokenType,
      expiresIn: currentSession.expiresIn,
      userId: currentSession.userId,
      username: username,
      role: currentSession.role,
    );

    await _sessionRestoreService.persistSession(updatedSession);
    state = state.copyWith(
      session: updatedSession,
      clearError: true,
    );
  }
}
