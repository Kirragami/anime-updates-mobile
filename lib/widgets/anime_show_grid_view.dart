import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../models/anime_show.dart';
import '../constants/app_constants.dart';
import '../providers/anime_providers.dart';
import 'anime_show_card.dart';
import '../theme/app_theme.dart';

class AnimeShowGridView extends ConsumerWidget {
  final List<AnimeShow> animeShowList;
  final Function(AnimeShow) onOpen;
  const AnimeShowGridView({
    super.key,
    required this.animeShowList,
    required this.onOpen,
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
    final trackedShowsNotifier = ref.read(trackedShowsNotifierProvider.notifier);
    final isLoadingMore = ref.watch(trackedListLoadingMoreProvider);

    final bool hasMore = trackedShowsNotifier.hasMore;
    final bool loadingMore = trackedShowsNotifier.isLoadingMore;
    final int pageSize = trackedShowsNotifier.pageSize;

    return AnimationLimiter(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200 &&
              hasMore &&
              !loadingMore) {
            trackedShowsNotifier.loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount(context),
            mainAxisExtent: 280,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: animeShowList.length + (isLoadingMore ? pageSize : 0),
          itemBuilder: (context, index) {
            if (index < animeShowList.length) {
              final animeShow = animeShowList[index];
              return AnimeShowCard(
                animeShow: animeShow,
                index: index,
                onOpen: () => onOpen(animeShow),
              );
            } else {
              return Container(
                margin: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: const _ShowGridItemSkeleton(),
              );
            }
          },
        ),
      ),
    );
  }
}

class _ShowGridItemSkeleton extends StatelessWidget {
  const _ShowGridItemSkeleton();

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
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeShowGridSkeleton extends StatelessWidget {
  const AnimeShowGridSkeleton({super.key});

  int _crossAxisCount(BuildContext context) {
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
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor,
      highlightColor: AppTheme.cardColor,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _crossAxisCount(context),
          mainAxisExtent: 280,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(AppConstants.smallPadding),
            decoration: BoxDecoration(
              color: AppTheme.cardColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: const _ShowGridItemSkeleton(),
          );
        },
      ),
    );
  }
}