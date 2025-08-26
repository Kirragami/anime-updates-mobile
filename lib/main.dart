import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/homepage_screen.dart';
import 'screens/torrent_test_screen.dart'; // Added import for torrent test screen
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';
import 'services/auth_service.dart';
import 'services/device_id_service.dart';
import 'services/fcm_registration_service.dart';
import 'services/auth_storage.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/firebase_config.dart';

/// Background handler for push notifications
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  print(message.data);
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
  
  // Setup background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Get device ID in background (don't await)
  DeviceIdService.getDeviceId().then((deviceId) {
    print("Device ID: $deviceId");
  }).catchError((error) {
    print("Error getting device ID: $error");
  });

  // Register stored FCM token in background
  FcmRegistrationService.registerStoredFcmToken();

  runApp(const ProviderScope(child: AnimeUpdatesApp()));
}

class AnimeUpdatesApp extends StatefulWidget {
  const AnimeUpdatesApp({super.key});

  @override
  State<AnimeUpdatesApp> createState() => _AnimeUpdatesAppState();
}

class _AnimeUpdatesAppState extends State<AnimeUpdatesApp> {
  String? _firebaseToken;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

    // Get the FCM token for display
    String? token = await messaging.getToken();
    print("Current FCM Token: $token");

    // Save the current token locally
    if (token != null) {
      await AuthStorage.saveFcmToken(token);
    }

    // Register the stored FCM token with backend (only if user is logged in)
    FcmRegistrationService.registerStoredFcmToken();

    setState(() {
      _firebaseToken = token;
    });

    // Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      // Save the new token locally
      await AuthStorage.saveFcmToken(newToken);
      // Re-register with backend when token refreshes (only if user is logged in)
      await FcmRegistrationService.registerFcmTokenWithRetry(newToken, 3);
    }).onError((err) {
      print("Error listening to token refresh: $err");
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message in foreground: ${message.notification?.title}");
      print(message.data);
    });

    // When user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("User tapped notification: ${message.notification?.title}");
      print(message.data);
      
      // Handle navigation to anime detail screen
      if (_navigatorKey.currentContext != null) {
        print('Attempting to navigate to anime detail from opened app');
        NotificationService.handleAnimeNotification(_navigatorKey.currentContext!, message.data);
      } else {
        print('Navigator context is null, cannot navigate');
      }
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App launched from notification: ${initialMessage.data}');
      
      // Handle navigation to anime detail screen when app is launched from notification
      if (_navigatorKey.currentContext != null) {
        print('Attempting to navigate to anime detail from initial message');
        NotificationService.handleAnimeNotification(_navigatorKey.currentContext!, initialMessage.data);
      } else {
        print('Navigator context is null, cannot navigate');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomepageScreen(
        fcmToken: _firebaseToken, // pass token if you want to show/debug it
      ),
      routes: {
        '/torrent-test': (context) => const TorrentTestScreen(), // Added route for torrent test screen
      },
    );
  }
}