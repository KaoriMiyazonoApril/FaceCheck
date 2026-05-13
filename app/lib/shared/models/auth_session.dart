import 'package:facecheck_app/shared/models/app_role.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    required this.username,
    required this.role,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final String username;
  final AppRole role;

  bool get isAdmin => role == AppRole.admin;

  factory AuthSession.fromLoginPayload(Object? payload) {
    final root = _asMap(payload);
    final user = _asMap(root['user']);

    return AuthSession(
      accessToken: root['accessToken']?.toString() ?? '',
      tokenType: root['tokenType']?.toString() ?? 'Bearer',
      expiresIn: (root['expiresIn'] as num?)?.toInt() ?? 0,
      userId: user['userId']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      role: AppRole.fromBackend(user['role'] ?? root['role']),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: AppRole.fromBackend(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
      'userId': userId,
      'username': username,
      'role': role.backendValue,
    };
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
    throw const FormatException('Expected an object payload.');
  }
}
