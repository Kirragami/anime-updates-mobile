import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';
import 'auth_storage.dart';
import 'fcm_registration_service.dart';
import 'dio_client.dart';

class AuthService {
  // Configurable endpoints - change these easily
  static const String _baseUrl = AppConstants.baseUrl;
  static const String _loginEndpoint = AppConstants.loginEndpoint;
  static const String _registerEndpoint = AppConstants.registerEndpoint;
  static const String _logoutEndpoint = AppConstants.logoutEndpoint;
  static const String _refreshEndpoint = AppConstants.refreshEndpoint;
  static const String _profileEndpoint = AppConstants.profileEndpoint;

  // Get full URLs
  static String get loginUrl => '$_baseUrl$_loginEndpoint';
  static String get registerUrl => '$_baseUrl$_registerEndpoint';
  static String get logoutUrl => '$_baseUrl$_logoutEndpoint';
  static String get refreshUrl => '$_baseUrl$_refreshEndpoint';
  static String get profileUrl => '$_baseUrl$_profileEndpoint';

  // Authentication token storage
  static String? _accessToken;
  static String? _refreshToken;
  static User? _currentUser;

  // Getters
  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _accessToken != null;

  // Headers for authenticated requests
  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // Login method
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.post(
        loginUrl,
        data: jsonEncode({
          // API expects these exact keys
          'userName': username,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        final data = response.data as Map<String, dynamic>;

        // New response: { accessToken, refreshToken }
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];

        // Try to derive username from JWT if possible
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

        // Persist tokens and minimal user info
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

        // Register FCM token with backend
        // Run in background, don't block login
        // Register the stored FCM token
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

  // Register method
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.post(
        registerUrl,
        data: jsonEncode({
          // Only username and password are required
          'userName': username,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        final data = response.data as Map<String, dynamic>;
        // Response only contains success indicator
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

  // Logout method
  static Future<Map<String, dynamic>> logout() async {
    try {
      if (_accessToken != null) {
        await dioClient.post(
          logoutUrl,
          options: Options(
            headers: _authHeaders,
          ),
        );
      }
      
      // Clear local data
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      await AuthStorage.clear();
      
      return {
        'success': true,
        'message': 'Logout successful',
      };
    } catch (e) {
      // Even if the request fails, clear local data
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      
      return {
        'success': true,
        'message': 'Logout successful (local)',
        'warning': 'Network request failed but logged out locally',
      };
    }
  }

  // Refresh token method
  static Future<Map<String, dynamic>> refreshAccessToken() async {
    try {
      if (_refreshToken == null) {
        return {
          'success': false,
          'message': 'No refresh token available',
          'error': 'No refresh token',
        };
      }

      final response = await dioClient.post(
        refreshUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_refreshToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        
        // Save the new tokens
        await AuthStorage.saveAccessToken(_accessToken!);
        await AuthStorage.saveRefreshToken(_refreshToken);
        
        return {
          'success': true,
          'message': 'Token refreshed',
        };
      } else {
        // Refresh failed, clear tokens
        _accessToken = null;
        _refreshToken = null;
        _currentUser = null;
        
        return {
          'success': false,
          'message': 'Token refresh failed',
          'error': 'Invalid refresh token',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during refresh',
        'error': e.toString(),
      };
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dioClient.get(
        profileUrl,
        options: Options(
          headers: _authHeaders,
        ),
      );

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
        return {
          'success': false,
          'message': 'Failed to get profile',
          'error': 'Profile fetch failed',
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

  // Attempt to restore session from secure storage at app start
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
            // Fallback: derive minimal user from JWT
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
          // No stored user; derive minimal from JWT
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
        // Nothing to restore
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

  // Check if token is expired (JWT validation)
  static bool get isTokenExpired {
    if (_accessToken == null) return true;
    
    try {
      final payload = decodeJwtPayload(_accessToken!);
      if (payload == null) return true;
      
      // Check if 'exp' claim exists and is valid
      final exp = payload['exp'];
      if (exp is int) {
        final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        // Consider token expired if it's within 5 minutes of actual expiration
        return DateTime.now().isAfter(expirationTime.subtract(const Duration(minutes: 5)));
      }
      
      return true;
    } catch (_) {
      return true;
    }
  }

  // Clear all data (for testing or reset)
  static void clearData() {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
  }
} 