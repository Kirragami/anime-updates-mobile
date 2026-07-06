import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/anime_item.dart';
import '../screens/anime_detail_screen.dart';
import '../screens/login_screen.dart';
import '../screens/tomodachi_screen.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';

class NotificationService {
  static void handleRemoteMessage(
    BuildContext context,
    RemoteMessage message,
  ) {
    handleNotificationContent(
      context,
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
    );
  }

  static void handleNotificationContent(
    BuildContext context, {
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    if (isFriendNotification(data, body: body)) {
      _navigateToTomodachi(context);
      return;
    }

    if (!_isReleaseNotification(data)) {
      return;
    }

    try {
      final animeItem = AnimeItem.fromJson(data);
      _navigateToAnimeDetail(context, animeItem);
    } catch (_) {}
  }

  static bool isFriendMessage(RemoteMessage message) {
    return isFriendNotification(
      Map<String, dynamic>.from(message.data),
      body: message.notification?.body,
    );
  }

  static bool isFriendNotification(
    Map<String, dynamic> data, {
    String? body,
  }) {
    final type = (data['type'] ??
            data['notificationType'] ??
            data['notification_type'] ??
            '')
        .toString()
        .toLowerCase();

    if (type.contains('friend') || type.contains('tomodachi')) {
      return true;
    }

    final hasFriendFields = data.containsKey('username') ||
        data.containsKey('senderUsername') ||
        data.containsKey('sender_username');
    final hasReleaseFields = _isReleaseNotification(data);

    if (hasFriendFields && !hasReleaseFields) {
      return true;
    }

    if (data.containsKey('isSender') || data.containsKey('sender')) {
      return true;
    }

    final normalizedBody = (body ?? '').toLowerCase();
    if (normalizedBody.contains('tomodachi') ||
        normalizedBody.contains('wants to be your')) {
      return true;
    }

    return false;
  }

  static bool _isReleaseNotification(Map<String, dynamic> data) {
    final releaseId = (data['releaseId'] ?? '').toString();
    final animeShowId = (data['animeShowId'] ?? '').toString();
    final showTitle = (data['showTitle'] ?? '').toString();
    return releaseId.isNotEmpty ||
        animeShowId.isNotEmpty ||
        showTitle.isNotEmpty;
  }

  static void _navigateToTomodachi(BuildContext context) {
    const destination = TomodachiScreen();
    if (AuthService.isLoggedIn) {
      Navigator.of(context).push(
        CustomPageTransitions.simpleSlide(destination, fromRight: true),
      );
    } else {
      Navigator.of(context).push(
        CustomPageTransitions.simpleFade(
          LoginScreen(destination: destination),
        ),
      );
    }
  }

  static void _navigateToAnimeDetail(
    BuildContext context,
    AnimeItem animeItem,
  ) {
    Navigator.of(context).push(
      CustomPageTransitions.heroSlide(
        AnimeDetailScreen(anime: animeItem),
      ),
    );
  }
}
