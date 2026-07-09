import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logcat-visible watch party diagnostics (`adb logcat -s WatchParty flutter`).
class WatchPartyLogger {
  WatchPartyLogger._();

  static const _name = 'WatchParty';

  static void info(String message) {
    developer.log(message, name: _name);
    if (kDebugMode) {
      debugPrint('[$_name] $message');
    }
  }

  static void warn(String message) {
    developer.log(message, name: _name, level: 900);
    if (kDebugMode) {
      debugPrint('[$_name][WARN] $message');
    }
  }
}
