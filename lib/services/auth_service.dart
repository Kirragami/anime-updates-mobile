import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';
import 'auth_storage.dart';
import 'fcm_registration_service.dart';
import 'dio_client.dart';

class AuthService {
  static const String _baseUrl = AppConstants.baseUrl;
  static const String _loginEndpoint = AppConstants.loginEndpoint;
  static const String _registerEndpoint = AppConstants.registerEndpoint;
  static const String _logoutEndpoint = AppConstants.logoutEndpoint;
  static const String _refreshEndpoint = AppConstants.refreshEndpoint;
  static const String _profileEndpoint = AppConstants.profileEndpoint;

  static String get loginUrl => '$_baseUrl$_loginEndpoint';
  static String get registerUrl => '$_baseUrl$_registerEndpoint';
  static String get logoutUrl => '$_baseUrl$_logoutEndpoint';
  static String get refreshUrl => '$_baseUrl$_refreshEndpoint';
  static String get profileUrl => '$_baseUrl$_profileEndpoint';

  static String? _accessToken;
  static String? _refreshToken;
  static User? _currentUser;

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _accessToken != null;

  static String? get currentUserId {
    if (_accessToken == null) return null;
    final payload = decodeJwtPayload(_accessToken!);
    final sub = payload?['sub']?.toString();
    if (sub != null && sub.isNotEmpty) return sub;
    return _currentUser?.id.isNotEmpty == true ? _currentUser!.id : null;
  }

  static String? get currentUsername {
    if (_currentUser != null && _currentUser!.username.isNotEmpty) {
      return _currentUser!.username;
    }
    if (_accessToken == null) return null;
    final payload = decodeJwtPayload(_accessToken!);
    return payload?['username']?.toString();
  }

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.post(
        loginUrl,
        data: jsonEncode({
          'userName': username,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      ).timeout(Duration(seconds: 30));

      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        final data = response.data as Map<String, dynamic>;

        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];

        String derivedUsername = username;
        final payload = _accessToken != null ? decodeJwtPayload(_accessToken!) : null;
        if (payload != null && payload['username'] is String && (payload['username'] as String).isNotEmpty) {
          derivedUsername = payload['username'] as String;
        }

        _currentUser = User(
          id: '',
          email: '',
          username: derivedUsername,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        if (_accessToken != null) {
          await AuthStorage.saveAccessToken(_accessToken!);
        }
        await AuthStorage.saveRefreshToken(_refreshToken);
        await AuthStorage.saveUserJson({
          'id': _currentUser!.id,
          'email': _currentUser!.email,
          'username': _currentUser!.username,
          'created_at': _currentUser!.createdAt.toIso8601String(),
          'last_login_at': _currentUser!.lastLoginAt?.toIso8601String(),
        });

        FcmRegistrationService.registerStoredFcmToken();

        return {
          'success': true,
          'message': 'Login successful',
          'code': response.statusCode,
          'user': _currentUser,
        };
      } else {
        final errorData = response.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
          'error': errorData['error'] ?? 'Unknown error',
          'code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors, including server errors like 401
      if (e.response != null) {
        // Server responded with an error status code (4xx, 5xx)
        final errorData = e.response?.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Login failed',
          'error': errorData?['error'] ?? 'Server error',
          'code': e.response?.statusCode,
        };
      } else {
        // Network error or other issue
        return {
          'success': false,
          'message': 'Network error',
          'error': e.toString(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.post(
        registerUrl,
        data: jsonEncode({
          'userName': username,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      ).timeout(Duration(seconds: 30));

      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
          'code': response.statusCode,
        };
      } else {
        final errorData = response.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Registration failed',
          'error': errorData['error'] ?? 'Unknown error',
          'code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors, including server errors like 4xx, 5xx
      if (e.response != null) {
        // Server responded with an error status code (4xx, 5xx)
        final errorData = e.response?.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Registration failed',
          'error': errorData?['error'] ?? 'Server error',
          'code': e.response?.statusCode,
        };
      } else {
        // Network error or other issue
        return {
          'success': false,
          'message': 'Network error',
          'error': e.toString(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = _refreshToken;
      final fcmToken = await AuthStorage.getFcmToken();
      
      if (_accessToken != null) {
        final requestBody = <String, dynamic>{};
        if (refreshToken != null) {
          requestBody['refreshToken'] = refreshToken;
        }
        if (fcmToken != null) {
          requestBody['fcmToken'] = fcmToken;
        }
        
        await dioClient.post(
          logoutUrl,
          data: jsonEncode(requestBody),
          options: Options(
            headers: _authHeaders,
          ),
        ).timeout(Duration(seconds: 10));
      }
      
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      await AuthStorage.clear();
      
      return {
        'success': true,
        'message': 'Logout successful',
      };
    } catch (e) {
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      await AuthStorage.clear();
      
      return {
        'success': true,
        'message': 'Logout successful (local)',
        'warning': 'Network request failed but logged out locally',
      };
    }
  }

  static Future<Map<String, dynamic>>? _refreshFuture;

  static Future<Map<String, dynamic>> refreshAccessToken() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performTokenRefresh().whenComplete(() {
      _refreshFuture = null;
    });

    return _refreshFuture!;
  }

  static Future<Map<String, dynamic>> _performTokenRefresh() async {
    try {
      if (_refreshToken == null) {
        return {
          'success': false,
          'message': 'No refresh token available',
          'error': 'No refresh token',
        };
      }

      final refreshDio = Dio();
      
      final response = await refreshDio.post(
        refreshUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_refreshToken',
          },
        ),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        
        await AuthStorage.saveAccessToken(_accessToken!);
        await AuthStorage.saveRefreshToken(_refreshToken);
        
        return {
          'success': true,
          'message': 'Token refreshed',
        };
      } else {
        _accessToken = null;
        _refreshToken = null;
        _currentUser = null;
        
        final errorData = response.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Token refresh failed',
          'error': errorData?['error'] ?? 'Invalid refresh token',
          'code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors for refresh token
      if (e.response != null) {
        // Server responded with an error status code (4xx, 5xx)
        final errorData = e.response?.data;
        _accessToken = null;
        _refreshToken = null;
        _currentUser = null;
        
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Token refresh failed',
          'error': errorData?['error'] ?? 'Server error',
          'code': e.response?.statusCode,
        };
      } else {
        // Network error or other issue
        _accessToken = null;
        _refreshToken = null;
        _currentUser = null;
        
        return {
          'success': false,
          'message': 'Network error during refresh',
          'error': e.toString(),
        };
      }
    } catch (e) {
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      
      return {
        'success': false,
        'message': 'Network error during refresh',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dioClient.get(
        profileUrl,
        options: Options(
          headers: _authHeaders,
        ),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('user')) {
          _currentUser = User.fromJson(data['user']);
        }
        
        return {
          'success': true,
          'user': _currentUser,
        };
      } else {
        final errorData = response.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to get profile',
          'error': errorData?['error'] ?? 'Profile fetch failed',
          'code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors, including server errors
      if (e.response != null) {
        // Server responded with an error status code (4xx, 5xx)
        final errorData = e.response?.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to get profile',
          'error': errorData?['error'] ?? 'Server error',
          'code': e.response?.statusCode,
        };
      } else {
        // Network error or other issue
        return {
          'success': false,
          'message': 'Network error',
          'error': e.toString(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error',
        'error': e.toString(),
      };
    }
  }

  static Future<void> restoreSession() async {
    try {
      final storedAccess = await AuthStorage.getAccessToken();
      final storedRefresh = await AuthStorage.getRefreshToken();
      final storedUser = await AuthStorage.getUserJson();

      if (storedAccess != null && storedAccess.isNotEmpty) {
        _accessToken = storedAccess;
        _refreshToken = storedRefresh;
        if (storedUser != null) {
          try {
            _currentUser = User.fromJson(storedUser);
          } catch (_) {
            final payload = decodeJwtPayload(storedAccess);
            final sub = (payload != null && payload['sub'] is String) ? payload['sub'] as String : '';
            _currentUser = User(
              id: storedUser['id']?.toString() ?? '',
              email: storedUser['email']?.toString() ?? '',
              username: storedUser['username']?.toString() ?? sub,
              createdAt: DateTime.tryParse(storedUser['created_at']?.toString() ?? '') ?? DateTime.now(),
              lastLoginAt: DateTime.tryParse(storedUser['last_login_at']?.toString() ?? ''),
            );
          }
        } else {
          final payload = decodeJwtPayload(storedAccess);
          final sub = (payload != null && payload['sub'] is String) ? payload['sub'] as String : '';
          _currentUser = User(
            id: '',
            email: '',
            username: sub,
            createdAt: DateTime.now(),
            lastLoginAt: null,
          );
        }
      } else {
        _accessToken = null;
        _refreshToken = null;
        _currentUser = null;
      }
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
    }
  }

  static bool get isTokenExpired {
    if (_accessToken == null) return true;
    
    try {
      final payload = decodeJwtPayload(_accessToken!);
      if (payload == null) return true;
      
      final exp = payload['exp'];
      if (exp is int) {
        final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expirationTime.subtract(const Duration(minutes: 5)));
      }
      
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> ensureFreshAccessToken() async {
    if (!isTokenExpired) {
      return;
    }

    final result = await refreshAccessToken();
    if (result['success'] != true) {
      throw Exception('Session expired. Please log in again.');
    }
  }

  static void clearData() {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
  }
}