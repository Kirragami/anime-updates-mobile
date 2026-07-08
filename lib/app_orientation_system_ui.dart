import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Global system UI: landscape uses immersive mode; portrait restores normal overlays.
class AppOrientationSystemUi {
  AppOrientationSystemUi._();

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static bool get isLandscape {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return false;
    final view = views.first;
    final dpr = view.devicePixelRatio;
    if (dpr == 0) return false;
    final width = view.physicalSize.width / dpr;
    final height = view.physicalSize.height / dpr;
    return width > height;
  }

  /// Orientations matching the current device layout before entering the player.
  static List<DeviceOrientation> get layoutOrientations {
    return orientationsFor(
      isLandscape ? Orientation.landscape : Orientation.portrait,
    );
  }

  static List<DeviceOrientation> orientationsFor(Orientation orientation) {
    if (orientation == Orientation.landscape) {
      return const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
    return const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];
  }

  static List<DeviceOrientation> orientationsFromContext(BuildContext context) {
    return orientationsFor(MediaQuery.orientationOf(context));
  }

  /// Call after rotation, app start, or any route that overrides [SystemChrome] (e.g. video player).
  static void sync() {
    final landscape = isLandscape;

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
