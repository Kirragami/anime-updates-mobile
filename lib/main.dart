import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/homepage_screen.dart';
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';
import 'services/auth_service.dart';
import 'services/device_id_service.dart';
import 'services/fcm_registration_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/firebase_config.dart';

/// Background handler for push notifications
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseConfig.firebaseOptions,
  );
  print("firebase init done");

  // Restore user session
  await AuthService.restoreSession();
  print("session restore done");
  
  // Get device ID
  final deviceId = await DeviceIdService.getDeviceId();
  print("Device ID: $deviceId");

  // Setup background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: AnimeUpdatesApp()));
}

class AnimeUpdatesApp extends StatefulWidget {
  const AnimeUpdatesApp({super.key});

  @override
  State<AnimeUpdatesApp> createState() => _AnimeUpdatesAppState();
}

class _AnimeUpdatesAppState extends State<AnimeUpdatesApp> {
  String? _firebaseToken;

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permission (required on Android 13+ and iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Check and update FCM token on app launch
    await FcmRegistrationService.checkAndUpdateFcmToken();

    // Get the FCM token for display
    String? token = await messaging.getToken();
    print("Current FCM Token: $token");

    setState(() {
      _firebaseToken = token;
    });

    // Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      // Re-register with backend when token refreshes (only if user is logged in)
      await FcmRegistrationService.registerFcmTokenWithRetry(newToken, 3);
    }).onError((err) {
      print("Error listening to token refresh: $err");
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message in foreground: ${message.notification?.title}");
    });

    // When user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("User tapped notification: ${message.notification?.title}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomepageScreen(
        fcmToken: _firebaseToken, // pass token if you want to show/debug it
      ),
    );
  }
}
