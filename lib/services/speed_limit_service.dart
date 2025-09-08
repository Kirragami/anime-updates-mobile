import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SpeedLimitService {
  static final SpeedLimitService _instance = SpeedLimitService._internal();
  factory SpeedLimitService() => _instance;
  SpeedLimitService._internal();

  static const String _speedLimitKey = 'download_speed_limit';
  static const double _defaultSpeedLimit = 0.0; // KB/s (0 = unlimited)

  double _currentSpeedLimit = _defaultSpeedLimit;
  bool _isInitialized = false;

  /// Initialize the service and load the speed limit from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSpeedLimit = prefs.getDouble(_speedLimitKey) ?? _defaultSpeedLimit;
      _isInitialized = true;

      if (kDebugMode) {
        print('Speed limit initialized: $_currentSpeedLimit KB/s');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing speed limit service: $e');
      }
      _currentSpeedLimit = _defaultSpeedLimit;
      _isInitialized = true;
    }
  }

  /// Get the current speed limit in KB/s
  double get speedLimit => _currentSpeedLimit;

  /// Set the speed limit in KB/s
  Future<void> setSpeedLimit(double speedLimitKBps) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Clamp the value between 0 and 10000 KB/s
    _currentSpeedLimit = speedLimitKBps.clamp(0.0, 10000.0);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedLimitKey, _currentSpeedLimit);

      if (kDebugMode) {
        print('Speed limit updated: $_currentSpeedLimit KB/s');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving speed limit: $e');
      }
    }
  }

  /// Get speed limit in bytes per second
  int get speedLimitBytesPerSecond => (_currentSpeedLimit * 1024).round();

  /// Check if speed limiting is enabled (speed limit > 0)
  bool get isSpeedLimited => _currentSpeedLimit > 0;

  /// Reset to default speed limit
  Future<void> resetToDefault() async {
    await setSpeedLimit(_defaultSpeedLimit);
  }

  /// Get speed limit as a formatted string
  String get formattedSpeedLimit {
    if (_currentSpeedLimit == 0) {
      return 'Unlimited';
    } else if (_currentSpeedLimit >= 1000) {
      return '${(_currentSpeedLimit / 1000).toStringAsFixed(1)} MB/s';
    } else {
      return '${_currentSpeedLimit.toStringAsFixed(0)} KB/s';
    }
  }
}
