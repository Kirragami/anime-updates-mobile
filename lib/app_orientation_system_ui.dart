import 'dart:ui';

import 'package:flutter/services.dart';

/// Global system UI: landscape uses immersive mode; portrait restores normal overlays.
class AppOrientationSystemUi {
  AppOrientationSystemUi._();

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Call after rotation, app start, or any route that overrides [SystemChrome] (e.g. video player).
  static void sync() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return;
    final view = views.first;
    final dpr = view.devicePixelRatio;
    if (dpr == 0) return;
    final width = view.physicalSize.width / dpr;
    final height = view.physicalSize.height / dpr;
    final landscape = width > height;

    if (landscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }
}
