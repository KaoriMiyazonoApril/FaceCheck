import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: FaceCheckApp()));
}

class FaceCheckApp extends ConsumerStatefulWidget {
  const FaceCheckApp({super.key});

  @override
  ConsumerState<FaceCheckApp> createState() => _FaceCheckAppState();
}

class _FaceCheckAppState extends ConsumerState<FaceCheckApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(authStateNotifierProvider.notifier).restoreSession();
      } catch (_) {
        // Secure storage may be unavailable on some emulators;
        // the app should still render the login page.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FaceCheck',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        useMaterial3: true,
      ),
    );
  }
}
