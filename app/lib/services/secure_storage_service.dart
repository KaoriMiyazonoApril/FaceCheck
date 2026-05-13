import 'dart:convert';

import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class SecureStorageService {
  SecureStorageService(this._store);

  static const String _sessionKey = 'auth.session';

  final SecureKeyValueStore _store;

  Future<AuthSession?> readSession() async {
    final rawValue = await _store.read(_sessionKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map) {
      return null;
    }

    return AuthSession.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<String?> readAccessToken() async {
    return (await readSession())?.accessToken;
  }

  Future<void> writeSession(AuthSession session) {
    return _store.write(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() {
    return _store.delete(_sessionKey);
  }
}
