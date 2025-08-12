import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../constants/app_constants.dart';

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
  static bool get isLoggedIn => _accessToken != null && _currentUser != null;

  // Headers for authenticated requests
  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // Login method
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _currentUser = User.fromJson(data['user']);
        
        return {
          'success': true,
          'message': 'Login successful',
          'user': _currentUser,
        };
      } else {
        final errorData = jsonDecode(response.body);
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
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      if (password != confirmPassword) {
        return {
          'success': false,
          'message': 'Passwords do not match',
          'error': 'Password mismatch',
        };
      }

      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'password_confirmation': confirmPassword,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _currentUser = User.fromJson(data['user']);
        
        return {
          'success': true,
          'message': 'Registration successful',
          'user': _currentUser,
        };
      } else {
        final errorData = jsonDecode(response.body);
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
        await http.post(
          Uri.parse(logoutUrl),
          headers: _authHeaders,
        );
      }
      
      // Clear local data
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      
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

      final response = await http.post(
        Uri.parse(refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': _refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        
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
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        
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

  // Check if token is expired (simple check)
  static bool get isTokenExpired {
    // This is a simple check - you might want to implement JWT decoding
    // For now, we'll assume tokens are valid if they exist
    return _accessToken == null;
  }

  // Clear all data (for testing or reset)
  static void clearData() {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
  }
} 