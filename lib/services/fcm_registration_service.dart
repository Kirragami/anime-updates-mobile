import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/app_constants.dart';
import '../services/device_id_service.dart';
import '../services/auth_service.dart'; // For access token
import '../services/auth_storage.dart'; // For FCM token storage

class FcmRegistrationService {
  static const String _fcmRegisterEndpoint = '/api/fcm/register';
  static const String _baseUrl = AppConstants.baseUrl;
  static bool _isRegistering = false;

  /// Register the FCM token with the backend
  /// 
  /// This method is safe to call multiple times as it has a lock to prevent
  /// concurrent registrations.
  /// Only registers if user is logged in
  static Future<bool> registerFcmToken(String fcmToken) async {
    // Only register if user is logged in
    if (!AuthService.isLoggedIn) {
      print('User not logged in, skipping FCM token registration');
      // Still save the token locally for future use
      await AuthStorage.saveFcmToken(fcmToken);
      return false;
    }
    
    // Prevent concurrent registrations
    if (_isRegistering) {
      print('FCM registration already in progress, skipping...');
      return false;
    }

    _isRegistering = true;
    
    try {
      // Get the device ID
      final deviceId = await DeviceIdService.getDeviceId();
      
      // Prepare the request payload
      final payload = {
        'token': fcmToken,
        'deviceId': deviceId,
      };
      
      // Make the HTTP request
      final url = Uri.parse('$_baseUrl$_fcmRegisterEndpoint');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Include auth token if available (required for backend)
          if (AuthService.accessToken != null)
            'Authorization': 'Bearer ${AuthService.accessToken}',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('FCM token registered successfully');
        // Save the token after successful registration
        await AuthStorage.saveFcmToken(fcmToken);
        return true;
      } else {
        print('Failed to register FCM token. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error registering FCM token: $e');
      return false;
    } finally {
      _isRegistering = false;
    }
  }
  
  /// Register FCM token with retry logic
  /// Only registers if user is logged in
  static Future<bool> registerFcmTokenWithRetry(String fcmToken, int maxRetries) async {
    // Only register if user is logged in
    if (!AuthService.isLoggedIn) {
      print('User not logged in, skipping FCM token registration');
      // Still save the token locally for future use
      await AuthStorage.saveFcmToken(fcmToken);
      return false;
    }
    
    for (int i = 0; i <= maxRetries; i++) {
      final success = await registerFcmToken(fcmToken);
      if (success) {
        return true;
      }
      
      // Wait before retrying (exponential backoff)
      if (i < maxRetries) {
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    
    print('Failed to register FCM token after $maxRetries retries');
    return false;
  }
  
  /// Check and update FCM token on app launch
  /// Gets the current FCM token and compares with stored one
  /// If different and user is logged in, registers the new token with backend
  static Future<String?> checkAndUpdateFcmToken() async {
    try {
      // Get the current FCM token
      final currentFcmToken = await FirebaseMessaging.instance.getToken();
      
      if (currentFcmToken == null) {
        print('Current FCM token is null');
        return null;
      }
      
      // Get the stored FCM token
      final storedFcmToken = await AuthStorage.getFcmToken();
      
      // Save the current token locally regardless of login status
      await AuthStorage.saveFcmToken(currentFcmToken);
      
      // If tokens are different or no stored token, and user is logged in, register the new one
      if ((storedFcmToken != currentFcmToken) && AuthService.isLoggedIn) {
        print('FCM token has changed or is new, and user is logged in. Registering with backend...');
        print('Old token: $storedFcmToken');
        print('New token: $currentFcmToken');
        
        // Register the new token
        await registerFcmTokenWithRetry(currentFcmToken, 3);
      } else if (storedFcmToken != currentFcmToken) {
        print('FCM token has changed but user is not logged in. Saved locally for future registration.');
      } else {
        print('FCM token is unchanged');
      }
      
      return currentFcmToken;
    } catch (e) {
      print('Error checking FCM token: $e');
      return null;
    }
  }
}