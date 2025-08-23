import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../services/device_id_service.dart';
import '../services/auth_service.dart'; // For access token
import '../services/auth_storage.dart'; // For FCM token storage
import 'dio_client.dart';

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
      final url = '$_baseUrl$_fcmRegisterEndpoint';
      final response = await dioClient.post(
        url,
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            // Include auth token if available (required for backend)
            if (AuthService.accessToken != null)
              'Authorization': 'Bearer ${AuthService.accessToken}',
          },
        ),
      );
      
      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        print('FCM token registered successfully');
        // Save the token after successful registration
        await AuthStorage.saveFcmToken(fcmToken);
        return true;
      } else {
        print('Failed to register FCM token. Status: ${response.statusCode}');
        print('Response body: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error registering FCM token: $e');
      return false;
    } finally {
      _isRegistering = false;
    }
  }
  
  /// Register FCM token without checking if it's different
  /// Only registers if user is logged in
  static Future<bool> registerStoredFcmToken() async {
    // Only register if user is logged in
    if (!AuthService.isLoggedIn) {
      print('User not logged in, skipping FCM token registration');
      return false;
    }
    
    try {
      // Get the stored FCM token
      final storedFcmToken = await AuthStorage.getFcmToken();
      
      if (storedFcmToken == null) {
        print('No stored FCM token found');
        return false;
      }
      
      print('Registering stored FCM token with backend...');
      print('Token: $storedFcmToken');
      
      // Register the stored token
      return await registerFcmToken(storedFcmToken);
    } catch (e) {
      print('Error registering stored FCM token: $e');
      return false;
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
}