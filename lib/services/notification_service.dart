import 'package:flutter/material.dart';
import '../models/anime_item.dart';
import '../screens/anime_detail_screen.dart';
import '../utils/page_transitions.dart';

class NotificationService {
  /// Handles notification data and navigates to the anime detail screen
  /// The notification data is expected to contain a complete anime_item model
  static void handleAnimeNotification(BuildContext context, Map<String, dynamic> data) {
    try {
      // Parse anime data directly from notification - assuming it's a complete anime_item model
      final animeItem = AnimeItem.fromJson(data);
      
      // Navigate to anime detail screen
      _navigateToAnimeDetail(context, animeItem);
    } catch (e) {
      // In production, you might want to use a logging service instead
      // For now, we'll just silently fail
    }
  }

  /// Navigates to the anime detail screen
  static void _navigateToAnimeDetail(BuildContext context, AnimeItem animeItem) {
    Navigator.of(context).push(
      CustomPageTransitions.heroSlide(
        AnimeDetailScreen(anime: animeItem),
      ),
    );
  }
}