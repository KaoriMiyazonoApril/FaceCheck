import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef AccessTokenReader = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.readAccessToken,
  });

  final AccessTokenReader readAccessToken;

  @visibleForTesting
  Future<Map<String, dynamic>> authorizedHeaders(
    Map<String, dynamic> headers,
  ) async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) {
      return headers;
    }

    return <String, dynamic>{
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final headers = await authorizedHeaders(
      Map<String, dynamic>.from(options.headers),
    );
    options.headers
      ..clear()
      ..addAll(headers);
    handler.next(options);
  }
}
