import 'package:flutter/foundation.dart';

class AppEnv {
  const AppEnv({
    required this.baseUrl,
    required this.localBackendHosts,
  });

  final String baseUrl;
  final List<String> localBackendHosts;

  factory AppEnv.current() {
    if (kIsWeb) {
      return const AppEnv(
        baseUrl: 'http://localhost:8080',
        localBackendHosts: <String>['localhost'],
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const AppEnv(
          baseUrl: 'http://10.0.2.2:8080',
          localBackendHosts: <String>['10.0.2.2', '127.0.0.1', 'localhost'],
        );
      default:
        return const AppEnv(
          baseUrl: 'http://127.0.0.1:8080',
          localBackendHosts: <String>['127.0.0.1', 'localhost'],
        );
    }
  }
}
