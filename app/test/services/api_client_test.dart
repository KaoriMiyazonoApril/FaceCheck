import 'package:dio/dio.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
    test('unwraps backend success envelopes', () {
      final value = ApiClient.unwrapEnvelope<int>(
        <String, Object>{
          'success': true,
          'data': <String, Object>{'count': 3},
        },
        (Object? json) {
          final payload = json as Map<String, Object?>;
          return payload['count'] as int;
        },
      );

      expect(value, 3);
    });

    test('normalizes backend error envelopes', () {
      final requestOptions = RequestOptions(path: '/api/auth/login');
      final exception = DioException(
        requestOptions: requestOptions,
        response: Response<Object?>(
          requestOptions: requestOptions,
          statusCode: 401,
          data: <String, Object>{
            'success': false,
            'error': <String, Object>{
              'code': 'INVALID_CREDENTIALS',
              'message': 'Username or password is incorrect.',
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final normalized = ApiClient.normalizeException(exception);

      expect(normalized, isA<BackendApiException>());
      expect(normalized.code, 'INVALID_CREDENTIALS');
      expect(normalized.statusCode, 401);
      expect(normalized.message, 'Username or password is incorrect.');
    });

    test('normalizes TLS certificate failures', () {
      final normalized = ApiClient.normalizeException(
        DioException(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          type: DioExceptionType.badCertificate,
        ),
      );

      expect(normalized.code, 'TLS_CERTIFICATE_ERROR');
      expect(normalized.message, 'Unable to verify the backend certificate.');
    });
  });

  group('AuthInterceptor', () {
    test('injects bearer token when one exists', () async {
      final interceptor = AuthInterceptor(
        readAccessToken: () async => 'jwt-token',
      );

      final headers = await interceptor.authorizedHeaders(
        <String, dynamic>{'Accept': 'application/json'},
      );

      expect(headers['Authorization'], 'Bearer jwt-token');
      expect(headers['Accept'], 'application/json');
    });
  });
}
