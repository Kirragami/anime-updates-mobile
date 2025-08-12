import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/anime_item.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_grid_view.dart';
import '../widgets/loading_widget.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';

class AnimeListScreen extends ConsumerStatefulWidget {
  const AnimeListScreen({super.key});

  @override
  ConsumerState<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends ConsumerState<AnimeListScreen>
    with TickerProviderStateMixin {
  late RefreshController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(initialRefresh: false);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure download operations provider initializes to check existing files
    ref.watch(downloadOperationsNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeListAsync = ref.watch(animeListNotifierProvider);
                    
                    return animeListAsync.when(
                      data: (animeList) => _buildAnimeList(animeList),
                      loading: () => const AnimeGridSkeleton(),
                      error: (error, stack) => _buildErrorWidget(error),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Stack(
      children: [
        // Main app bar content
        Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Newest Releases',
                      style: AppTheme.heading2.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Download latest released episodes',
                      style: AppTheme.body2.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final activeDownloads = ref.watch(activeDownloadCountProvider);
                  final downloadedCount = ref.watch(downloadedCountProvider);
                  
                  if (activeDownloads > 0 || downloadedCount > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activeDownloads > 0 ? '$activeDownloads' : '$downloadedCount',
                            style: AppTheme.body2.copyWith(
                              color: activeDownloads > 0 ? AppTheme.primaryColor : AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: const Duration(seconds: 2));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        
        // Sasha swinging GIF positioned at top right
        Positioned(
          top: 0, // Stick to the very top
          right: 20,
          child: Image.asset(
            'assets/gifs/sasha-swing.gif',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.animation_rounded,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeList(List<AnimeItem> animeList) {
    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: false,
      header: const WaterDropHeader(
        waterDropColor: AppTheme.primaryColor,
      ),
      onRefresh: () async {
        await ref.read(animeListNotifierProvider.notifier).refresh();
        _refreshController.refreshCompleted();
      },
      child: AnimeGridView(
        animeList: animeList,
        onDownload: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).downloadAnime(anime),
        onDelete: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).deleteDownload(anime),
        onOpen: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).openDownloadedFile(anime),
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: AppTheme.heading3.copyWith(
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTheme.body2.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(animeListNotifierProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }


} 