import 'package:facecheck_app/features/auth/auth_state_notifier.dart';
import 'package:facecheck_app/features/auth/session_restore_service.dart';
import 'package:facecheck_app/router/app_router.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_api_service.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/config/app_env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appEnvProvider = Provider<AppEnv>((Ref ref) => AppEnv.current());

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>(
  (Ref ref) => FlutterSecureKeyValueStore(),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (Ref ref) => SecureStorageService(ref.watch(secureKeyValueStoreProvider)),
);

final sessionRestoreServiceProvider = Provider<SessionRestoreService>(
  (Ref ref) => SessionRestoreService(ref.watch(secureStorageServiceProvider)),
);

final authInterceptorProvider = Provider<AuthInterceptor>(
  (Ref ref) => AuthInterceptor(
    readAccessToken: ref.read(secureStorageServiceProvider).readAccessToken,
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (Ref ref) => ApiClient(
    baseUrl: ref.watch(appEnvProvider).baseUrl,
    authInterceptor: ref.watch(authInterceptorProvider),
  ),
);

final authApiProvider = Provider<AuthApi>(
  (Ref ref) => DioAuthApiService(ref.watch(apiClientProvider)),
);

final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>(
  (Ref ref) => AuthStateNotifier(
    authApi: ref.watch(authApiProvider),
    sessionRestoreService: ref.watch(sessionRestoreServiceProvider),
  ),
);

final appRouterProvider = Provider<GoRouter>(
  (Ref ref) => AppRouter.buildRouter(
    session: ref.watch(authStateNotifierProvider).session,
  ),
);
