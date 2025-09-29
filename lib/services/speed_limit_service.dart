import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SpeedLimitService {
  static final SpeedLimitService _instance = SpeedLimitService._internal();
  factory SpeedLimitService() => _instance;
  SpeedLimitService._internal();

  static const String _speedLimitKey = 'download_speed_limit';
  static const double _defaultSpeedLimit = 0.0; 

  double _currentSpeedLimit = _defaultSpeedLimit;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSpeedLimit = prefs.getDouble(_speedLimitKey) ?? _defaultSpeedLimit;
      _isInitialized = true;

    } catch (e) {
      _currentSpeedLimit = _defaultSpeedLimit;
      _isInitialized = true;
    }
  }

  double get speedLimit => _currentSpeedLimit;

  Future<void> setSpeedLimit(double speedLimitKBps) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentSpeedLimit = speedLimitKBps.clamp(0.0, 50000.0);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedLimitKey, _currentSpeedLimit);

    } catch (e) {
    }
  }

  int get speedLimitBytesPerSecond => (_currentSpeedLimit * 1024).round();

  bool get isSpeedLimited => _currentSpeedLimit > 0;

  Future<void> resetToDefault() async {
    await setSpeedLimit(_defaultSpeedLimit);
  }

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
