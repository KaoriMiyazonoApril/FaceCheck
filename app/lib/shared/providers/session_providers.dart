import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentSessionProvider = Provider(
  (Ref ref) => ref.watch(authStateNotifierProvider).session,
);

final isAuthenticatedProvider = Provider(
  (Ref ref) => ref.watch(currentSessionProvider) != null,
);

final isAdminProvider = Provider(
  (Ref ref) => ref.watch(currentSessionProvider)?.isAdmin ?? false,
);

final baseUrlProvider = Provider(
  (Ref ref) => ref.watch(appEnvProvider).baseUrl,
);
