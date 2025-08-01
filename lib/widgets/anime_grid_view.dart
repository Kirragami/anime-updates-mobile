import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../models/anime_item.dart';
import '../constants/app_constants.dart';
import '../providers/anime_provider.dart';
import 'anime_grid_card.dart';

class AnimeGridView extends StatelessWidget {
  final List<AnimeItem> animeList;
  final Function(AnimeItem) onDownload;
  final Function(AnimeItem)? onDelete;
  final Function(AnimeItem)? onOpen;
  const AnimeGridView({
    super.key,
    required this.animeList,
    required this.onDownload,
    this.onDelete,
    this.onOpen,
  });

  int crossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 2;
    } else if (screenWidth < 800) {
      return 3;
    } else if (screenWidth < 1000) {
      return 4;
    } else if (screenWidth < 1200) {
      return 5;
    } else if (screenWidth < 1400) {
      return 6;
    } else {
      return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount(context),
          // childAspectRatio: 0.525,
          mainAxisExtent: 350,
          crossAxisSpacing: AppConstants.smallPadding,
          mainAxisSpacing: AppConstants.smallPadding,
        ),
        itemCount: animeList.length,
        itemBuilder: (context, index) {
          final anime = animeList[index];
          
          return Selector<AnimeProvider, Map<String, dynamic>>(
            selector: (context, provider) => {
              'isDownloading': provider.isDownloading(anime.id),
              'isDownloaded': provider.isDownloaded(anime.id),
              'downloadProgress': provider.getDownloadProgress(anime.id),
            },
            builder: (context, downloadState, child) {
              final isDownloading = downloadState['isDownloading'] as bool;
              final isDownloaded = downloadState['isDownloaded'] as bool;
              final progress = downloadState['downloadProgress'] as double;

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
          );
        },
      ),
    );
  }
} 