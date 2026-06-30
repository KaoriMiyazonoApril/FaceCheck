import 'package:dio/dio.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/services/backend_certificate_policy.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';

typedef JsonFactory<T> = T Function(Object? json);

class ApiClient {
  ApiClient({
    required String baseUrl,
    required AuthInterceptor authInterceptor,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const <String, Object>{
              'Accept': 'application/json',
            },
          ),
        ) {
    configureBackendCertificatePolicy(_dio, baseUrl);
    _dio.interceptors.add(authInterceptor);
  }

  final Dio _dio;

  Future<T> getEnvelope<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required JsonFactory<T> decoder,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
      return unwrapEnvelope(response.data, decoder);
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  Future<T> postEnvelope<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required JsonFactory<T> decoder,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return unwrapEnvelope(response.data, decoder);
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  Future<T> putEnvelope<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required JsonFactory<T> decoder,
  }) async {
    try {
      final response = await _dio.put<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return unwrapEnvelope(response.data, decoder);
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  Future<void> postNoContent(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      await _dio.post<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  Future<void> deleteNoContent(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      await _dio.delete<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  static T unwrapEnvelope<T>(Object? payload, JsonFactory<T> decoder) {
    final root = _asMap(payload);
    if (root['success'] != true) {
      throw _exceptionFromEnvelope(root, null);
    }
    return decoder(root['data']);
  }

  static BackendApiException normalizeException(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map || responseData is Map<String, dynamic>) {
      return _exceptionFromEnvelope(
        _asMap(responseData),
        error.response?.statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return BackendApiException(
          code: 'NETWORK_TIMEOUT',
          message: 'The request timed out.',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return BackendApiException(
          code: 'NETWORK_ERROR',
          message: 'Unable to reach the backend service.',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.badCertificate:
        return BackendApiException(
          code: 'TLS_CERTIFICATE_ERROR',
          message: 'Unable to verify the backend certificate.',
          statusCode: error.response?.statusCode,
        );
      default:
        return BackendApiException(
          code: 'UNKNOWN_ERROR',
          message: error.message ?? 'Unexpected backend error.',
          statusCode: error.response?.statusCode,
        );
    }
  }

  static BackendApiException _exceptionFromEnvelope(
    Map<String, dynamic> root,
    int? statusCode,
  ) {
    final error = _asMap(root['error']);
    return BackendApiException(
      code: error['code']?.toString() ?? 'UNKNOWN_ERROR',
      message: error['message']?.toString() ?? 'Unexpected backend error.',
      statusCode: statusCode,
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (Object? key, Object? innerValue) => MapEntry(
          key.toString(),
          innerValue,
        ),
      );
    }
    return const <String, dynamic>{};
  }
}
