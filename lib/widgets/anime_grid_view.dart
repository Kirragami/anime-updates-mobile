import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/anime_item.dart';
import '../constants/app_constants.dart';
import 'anime_grid_card.dart';

class AnimeGridView extends StatelessWidget {
  final List<AnimeItem> animeList;
  final Function(AnimeItem) onDownload;
  final Function(AnimeItem)? onDelete;
  final Function(AnimeItem)? onOpen;
  final Map<String, bool> downloadingItems;
  final Map<String, bool> downloadedItems;
  final Map<String, double> downloadProgress;

  const AnimeGridView({
    super.key,
    required this.animeList,
    required this.onDownload,
    this.onDelete,
    this.onOpen,
    this.downloadingItems = const {},
    this.downloadedItems = const {},
    this.downloadProgress = const {},
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.525,
          crossAxisSpacing: AppConstants.smallPadding,
          mainAxisSpacing: AppConstants.smallPadding,
        ),
        itemCount: animeList.length,
        itemBuilder: (context, index) {
          final anime = animeList[index];
          final isDownloading = downloadingItems[anime.id] ?? false;
          final isDownloaded = downloadedItems[anime.id] ?? false;
          final progress = downloadProgress[anime.id] ?? 0.0;

          return AnimeGridCard(
            anime: anime,
            index: index,
            isDownloading: isDownloading,
            isDownloaded: isDownloaded,
            downloadProgress: progress,
            onDownload: () => onDownload(anime),
            onDelete: onDelete != null ? () => onDelete!(anime) : null,
            onOpen: onOpen != null ? () => onOpen!(anime) : null,
          );
        },
      ),
    );
  }
} 