import 'package:flutter/material.dart';
import '../models/anime_item.dart';
import '../screens/anime_detail_screen.dart';
import '../utils/page_transitions.dart';

class NotificationService {
  static void handleAnimeNotification(BuildContext context, Map<String, dynamic> data) {
    try {
      final animeItem = AnimeItem.fromJson(data);
      
      _navigateToAnimeDetail(context, animeItem);
    } catch (e) {
    }
  }

  static void _navigateToAnimeDetail(BuildContext context, AnimeItem animeItem) {
    Navigator.of(context).push(
      CustomPageTransitions.heroSlide(
        AnimeDetailScreen(anime: animeItem),
      ),
    );
  }
}