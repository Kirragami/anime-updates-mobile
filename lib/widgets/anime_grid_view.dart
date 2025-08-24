import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../models/anime_item.dart';
import '../constants/app_constants.dart';
import '../providers/anime_providers.dart';
import 'anime_grid_card.dart';
import '../theme/app_theme.dart';

class AnimeGridView extends ConsumerWidget {
  final List<AnimeItem> animeList;
  final Function(AnimeItem) onDownload;
  final Function(AnimeItem)? onDelete;
  final Function(AnimeItem)? onOpen;
  final bool useTrackedProviders;
  const AnimeGridView({
    super.key,
    required this.animeList,
    required this.onDownload,
    this.onDelete,
    this.onOpen,
    this.useTrackedProviders = false,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final trackedNotifier = useTrackedProviders ? ref.read(trackedReleasesNotifierProvider.notifier) : null;
    final animeNotifier = useTrackedProviders ? null : ref.read(animeListNotifierProvider.notifier);
    final isLoadingMore = useTrackedProviders
        ? ref.watch(trackedListLoadingMoreProvider)
        : ref.watch(listLoadingMoreProvider);

    final bool hasMore = useTrackedProviders
        ? trackedNotifier!.hasMore
        : animeNotifier!.hasMore;
    final bool loadingMore = useTrackedProviders
        ? trackedNotifier!.isLoadingMore
        : animeNotifier!.isLoadingMore;
    final int pageSize = useTrackedProviders
        ? trackedNotifier!.pageSize
        : animeNotifier!.pageSize;

    return AnimationLimiter(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200 &&
              hasMore &&
              !loadingMore) {
            if (useTrackedProviders) {
              trackedNotifier!.loadMore();
            } else {
              animeNotifier!.loadMore();
            }
          }
          return false;
        },
        child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount(context),
          // childAspectRatio: 0.525,
          mainAxisExtent: 360,
          crossAxisSpacing: AppConstants.smallPadding,
          mainAxisSpacing: AppConstants.smallPadding,
        ),
          itemCount: animeList.length + (isLoadingMore ? pageSize : 0),
        itemBuilder: (context, index) {
            if (index < animeList.length) {
              final anime = animeList[index];
              return AnimeGridCard(
                anime: anime,
                index: index,
                onDownload: () => onDownload(anime),
                onDelete: onDelete != null ? () => onDelete!(anime) : null,
                onOpen: onOpen != null ? () => onOpen!(anime) : null,
                showTrackingIndicator: !useTrackedProviders,
              );
            } else {
              // Skeleton tile for loading more
              return Container(
                margin: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: const _GridItemSkeleton(),
              );
            }
        },
        ),
      ),
    );
  }
} 

class _GridItemSkeleton extends StatelessWidget {
  const _GridItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor,
      highlightColor: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 200,
                color: AppTheme.surfaceColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 16,
              width: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 12,
              width: MediaQuery.of(context).size.width * 0.2,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              height: 10,
              width: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}