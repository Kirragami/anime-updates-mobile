import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../services/device_id_service.dart';
import '../services/auth_service.dart'; 
import '../services/auth_storage.dart'; 
import 'dio_client.dart';

class FcmRegistrationService {
  static const String _fcmRegisterEndpoint = '/api/fcm/register';
  static const String _baseUrl = AppConstants.baseUrl;
  static bool _isRegistering = false;

  static Future<bool> registerFcmToken(String fcmToken) async {
    if (!AuthService.isLoggedIn) {
      await AuthStorage.saveFcmToken(fcmToken);
      return false;
    }
    
    if (_isRegistering) {
      return false;
    }

    _isRegistering = true;
    
    try {
      final deviceIdFuture = DeviceIdService.getDeviceId();
      
      final payload = {
        'token': fcmToken,
        'deviceId': await deviceIdFuture,
      };
      
      final url = '$_baseUrl$_fcmRegisterEndpoint';
      final response = await dioClient.post(
        url,
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (AuthService.accessToken != null)
              'Authorization': 'Bearer ${AuthService.accessToken}',
          },
        ),
      );
      
      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        await AuthStorage.saveFcmToken(fcmToken);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    } finally {
      _isRegistering = false;
    }
  }
  
  static void registerStoredFcmToken() {
    if (!AuthService.isLoggedIn) {
      return;
    }
    
    _registerStoredFcmTokenImpl().catchError((error) {
    });
  }
  
  static Future<void> _registerStoredFcmTokenImpl() async {
    try {
      final storedFcmToken = await AuthStorage.getFcmToken();
      
      if (storedFcmToken == null) {
        return;
      }
      
      
      await registerFcmToken(storedFcmToken);
    } catch (e) {
    }
  }
  
  static Future<bool> registerFcmTokenWithRetry(String fcmToken, int maxRetries) async {
    if (!AuthService.isLoggedIn) {
      await AuthStorage.saveFcmToken(fcmToken);
      return false;
    }
    
    for (int i = 0; i <= maxRetries; i++) {
      final success = await registerFcmToken(fcmToken);
      if (success) {
        return true;
      }
      
      if (i < maxRetries) {
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    
    return false;
  }
}