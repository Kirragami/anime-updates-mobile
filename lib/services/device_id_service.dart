import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static String? _deviceId;

  static Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    
    _deviceId = prefs.getString(_deviceIdKey);
    
    if (_deviceId == null) {
      _deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
    
    return _deviceId!;
  }

  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? _generateFallbackId();
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? _generateFallbackId();
    }
    
    return _generateFallbackId();
  }

  static String _generateFallbackId() {
    return 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystem}';
  }
}