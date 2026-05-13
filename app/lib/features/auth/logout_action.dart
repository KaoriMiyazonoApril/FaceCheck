import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LogoutAction {
  const LogoutAction._();

  static Future<void> execute(BuildContext context, WidgetRef ref) async {
    await ref.read(authStateNotifierProvider.notifier).logout();
    if (context.mounted) {
      context.go(AppRoutePaths.login);
    }
  }
}
