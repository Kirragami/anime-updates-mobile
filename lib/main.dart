import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_orientation_system_ui.dart';
import 'screens/homepage_screen.dart';
import 'screens/download_manager_screen.dart';
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';
import 'services/auth_service.dart';
import 'services/device_id_service.dart';
import 'services/fcm_registration_service.dart';
import 'services/auth_storage.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';
import 'providers/friends_providers.dart';
import 'services/active_downloads_manager.dart';
import 'services/completed_downloads_manager.dart';
import 'services/download_event_dispatcher.dart';
import 'services/playback_progress_manager.dart';
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

  // Initialize new download management system
  final downloadEventDispatcher = DownloadEventDispatcher();
  downloadEventDispatcher.initialize();
  
  final activeDownloadsManager = ActiveDownloadsManager();
  final completedDownloadsManager = CompletedDownloadsManager();
  
  // Initialize managers with native data
  await activeDownloadsManager.initialize();
  await completedDownloadsManager.initialize();
  
  // Initialize playback progress
  final playbackProgressManager = PlaybackProgressManager();
  await playbackProgressManager.initialize();
  
  // Start listening to events
  downloadEventDispatcher.startListening();
  
  print("Download management system initialized successfully");
  print("Active downloads: ${activeDownloadsManager.activeCount}");
  print("Completed downloads: ${completedDownloadsManager.completedCount}");

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

class AnimeUpdatesApp extends ConsumerStatefulWidget {
  const AnimeUpdatesApp({super.key});

  @override
  ConsumerState<AnimeUpdatesApp> createState() => _AnimeUpdatesAppState();
}

class _AnimeUpdatesAppState extends ConsumerState<AnimeUpdatesApp>
    with WidgetsBindingObserver {
  String? _firebaseToken;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  RemoteMessage? _pendingNotificationMessage;
  String? _pendingNotificationPayload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocalNotifications();
    _initFCM();
    _initNavigationChannel();
    WidgetsBinding.instance.addPostFrameCallback((_) => AppOrientationSystemUi.sync());
  }

  Future<void> _initLocalNotifications() async {
    await LocalNotificationService.initialize(
      onTap: (payload) {
        _pendingNotificationPayload = payload;
        _tryNavigateFromPendingNotification();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    AppOrientationSystemUi.sync();
  }

  Future<void> _initNavigationChannel() async {
    const navigationChannel = MethodChannel('com.aura.anime_updates/navigation');
    
    navigationChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'navigateToDownloadManager') {
        // Navigate to download manager screen when notification is tapped
        if (_navigatorKey.currentContext != null) {
          _navigateToDownloadManager();
        }
      }
    });
  }

  void _navigateToDownloadManager() {
    // Navigate to download manager screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigatorKey.currentContext != null) {
        // Check if we're not already on the download manager screen
        var currentRoute = ModalRoute.of(_navigatorKey.currentContext!);
        if (currentRoute?.settings.name != '/download-manager') {
          Navigator.of(_navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => const DownloadManagerScreen(),
            ),
          );
        }
      }
    });
  }

  void _scheduleNotificationNavigation(RemoteMessage message) {
    _pendingNotificationMessage = message;
    _tryNavigateFromPendingNotification();
  }

  void _tryNavigateFromPendingNotification() {
    if (_pendingNotificationMessage == null &&
        _pendingNotificationPayload == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null) {
        _tryNavigateFromPendingNotification();
        return;
      }

      final payload = _pendingNotificationPayload;
      if (payload != null) {
        _pendingNotificationPayload = null;
        LocalNotificationService.handlePayload(context, payload);
        return;
      }

      final message = _pendingNotificationMessage;
      if (message == null) {
        return;
      }

      _pendingNotificationMessage = null;
      NotificationService.handleRemoteMessage(context, message);
    });
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

    // Foreground messages — show as system notifications (FCM won't display them)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await LocalNotificationService.showRemoteMessage(message);

      if (NotificationService.isFriendMessage(message) &&
          AuthService.isLoggedIn) {
        ref.invalidate(tomodachiNotifierProvider);
      }
    });

    // When user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("User tapped notification: ${message.notification?.title}");
      print(message.data);
      _scheduleNotificationNavigation(message);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App launched from notification: ${initialMessage.data}');
      _scheduleNotificationNavigation(initialMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomepageScreen(),
    );
  }
}