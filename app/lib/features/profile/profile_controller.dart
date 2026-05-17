import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.role,
    required this.status,
  });

  final String userId;
  final String username;
  final String role;
  final String status;

  factory UserProfile.fromJson(Object? json) {
    final payload = json as Map<String, dynamic>;
    return UserProfile(
      userId: payload['userId']?.toString() ?? '',
      username: payload['username']?.toString() ?? '',
      role: payload['role']?.toString() ?? '',
      status: payload['status']?.toString() ?? '',
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchProfile() {
    return _apiClient.getEnvelope<UserProfile>(
      '/api/me/profile',
      decoder: UserProfile.fromJson,
    );
  }

  Future<UserProfile> updateProfile({
    required String username,
    required String password,
  }) {
    final body = <String, Object>{};
    if (username.trim().isNotEmpty) {
      body['username'] = username.trim();
    }
    if (password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    return _apiClient.putEnvelope<UserProfile>(
      '/api/me/profile',
      data: body,
      decoder: UserProfile.fromJson,
    );
  }
}

@immutable
class ProfileState {
  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  ProfileState copyWith({
    UserProfile? profile,
    bool clearProfile = false,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController({
    required ProfileRepository repository,
    required Future<void> Function(String username) updateSessionUsername,
  })  : _repository = repository,
        _updateSessionUsername = updateSessionUsername,
        super(const ProfileState());

  final ProfileRepository _repository;
  final Future<void> Function(String username) _updateSessionUsername;

  Future<void> loadProfile() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final profile = await _repository.fetchProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
        clearSuccess: true,
      );
    }
  }

  Future<bool> saveProfile({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final profile = await _repository.updateProfile(
        username: username,
        password: password,
      );
      await _updateSessionUsername(profile.username);
      state = state.copyWith(
        profile: profile,
        isSaving: false,
        successMessage: '个人资料已更新。',
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString(),
        clearSuccess: true,
      );
      return false;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (Ref ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>(
  (Ref ref) => ProfileController(
    repository: ref.watch(profileRepositoryProvider),
    updateSessionUsername:
        ref.read(authStateNotifierProvider.notifier).replaceUsername,
  ),
);
