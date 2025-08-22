import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUser = 'auth_user_json';
  static const String _keyFcmToken = 'fcm_token';

  static Future<void> saveAccessToken(String token) async {
    await _secure.write(key: _keyAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _secure.read(key: _keyAccessToken);
  }

  static Future<void> saveRefreshToken(String? token) async {
    if (token == null) {
      await _secure.delete(key: _keyRefreshToken);
    } else {
      await _secure.write(key: _keyRefreshToken, value: token);
    }
  }

  static Future<String?> getRefreshToken() async {
    return _secure.read(key: _keyRefreshToken);
  }

  static Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    await _secure.write(key: _keyUser, value: jsonEncode(userJson));
  }

  static Future<Map<String, dynamic>?> getUserJson() async {
    final value = await _secure.read(key: _keyUser);
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFcmToken(String token) async {
    await _secure.write(key: _keyFcmToken, value: token);
  }

  static Future<String?> getFcmToken() async {
    return _secure.read(key: _keyFcmToken);
  }

  static Future<void> clear() async {
    await _secure.delete(key: _keyAccessToken);
    await _secure.delete(key: _keyRefreshToken);
    await _secure.delete(key: _keyUser);
    await _secure.delete(key: _keyFcmToken);
  }
}

Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
