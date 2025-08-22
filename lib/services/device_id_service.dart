import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static String? _deviceId;

  /// Get the unique device ID
  /// 
  /// This will generate a new ID if one doesn't exist and save it to shared preferences
  static Future<String> getDeviceId() async {
    // Return cached ID if available
    if (_deviceId != null) {
      return _deviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Try to get existing ID from storage
    _deviceId = prefs.getString(_deviceIdKey);
    
    // If no ID exists, generate one
    if (_deviceId == null) {
      _deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
    
    return _deviceId!;
  }

  /// Generate a device-specific ID
  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // id is a 64-bit number (expressed as a hexadecimal string) that is 
      // randomly generated when the user first sets up the device and persists 
      // until wiped. It's intended to be stable.
      return androidInfo.id ?? _generateFallbackId();
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // identifierForVendor is a unique identifier tied to the vendor and device.
      // It remains the same until the user deletes all apps from the vendor.
      return iosInfo.identifierForVendor ?? _generateFallbackId();
    }
    
    // Fallback for other platforms
    return _generateFallbackId();
  }

  /// Generate a fallback UUID if platform-specific ID is not available
  static String _generateFallbackId() {
    // For now, we'll use a simple timestamp-based ID as a fallback
    // In a production app, you might want to use a proper UUID generator
    return 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystem}';
  }
}