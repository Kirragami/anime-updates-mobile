import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../providers/auth_provider.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_grid_view.dart';
import '../widgets/error_widget.dart' as error_widgets;
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';

import '../widgets/loading_widget.dart';
import '../models/anime_item.dart';
import '../models/anime_show.dart';
import '../widgets/anime_show_grid_view.dart';
import '../providers/download_providers.dart';
import '../app_orientation_system_ui.dart';
import 'anime_detail_screen.dart';
import 'video_player_screen.dart';

import 'profile_screen.dart';

class MyShowsScreen extends ConsumerStatefulWidget {
  const MyShowsScreen({super.key});

  @override
  ConsumerState<MyShowsScreen> createState() => _MyShowsScreenState();
}

class _MyShowsScreenState extends ConsumerState<MyShowsScreen>
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
    final userAsync = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              userAsync.when(
                data: (user) => _buildAppBar(context, ref, user),
                loading: () => _buildAppBar(context, ref, null),
                error: (error, stack) => _buildAppBar(context, ref, null),
              ),
              Expanded(
                child: userAsync.when(
                  data: (user) => _buildTrackedShowsList(),
                  loading: () => const AnimeShowGridSkeleton(),
                  error: (error, stack) => _buildErrorWidget(context, error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
         
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 14,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Shows',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user != null 
                      ? 'These are your favorite, ${user.username[0].toUpperCase()}${user.username.substring(1)}-sama'
                      : 'These are your favorite',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
     
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackedShowsList() {
    return Column(
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final trackedShowsAsync = ref.watch(trackedShowsNotifierProvider);
              return trackedShowsAsync.when(
                data: (shows) => SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  enablePullUp: false,
                  header: const WaterDropHeader(
                    waterDropColor: AppTheme.primaryColor,
                  ),
                  onRefresh: () async {
                    await ref.read(trackedShowsNotifierProvider.notifier).refresh();
                    _refreshController.refreshCompleted();
                  },
                  child: AnimeShowGridView(
                    animeShowList: shows,
                    onOpen: (animeShow) => _openAnimeShow(animeShow, ref),
                  ),
                ),
                loading: () => const AnimeShowGridSkeleton(),
                error: (error, stack) => _buildErrorWidget(context, error),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? 'User',
                  style: AppTheme.heading2.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'user@example.com',
                  style: AppTheme.body2.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppConstants.mediumAnimation).slideY(begin: 0.3);
  }



  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: AppTheme.heading2.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.body2.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppConstants.mediumAnimation).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
    return error_widgets.CustomErrorWidget(
      message: error.toString(),
      onRetry: () {
        
        final ref = ProviderScope.containerOf(context);
        ref.invalidate(trackedReleasesNotifierProvider);
      },
      showRetryButton: true,
    );
  }

  Future<void> _downloadAnime(AnimeItem anime, WidgetRef ref) async {
    try {
      await ref.read(activeDownloadsProvider.notifier).startDownload(
        releaseId: anime.id,
        magnetUrl: anime.downloadUrl,
        fileName: anime.fileName,
        showName: anime.title,
        episode: anime.episode,
        animeShowId: anime.animeShowId,
        imageUrl: anime.imageUrl,
        isTracked: anime.tracked,
      );
    } catch (e) {
   
    }
  }

  Future<void> _deleteAnime(AnimeItem anime, WidgetRef ref) async {
    try {
      final downloadStatus = ref.read(downloadStatusProvider(anime.id));
      
      if (downloadStatus.isActive) {
        await ref.read(activeDownloadsProvider.notifier).cancelDownload(anime.id);
      } else if (downloadStatus.isCompleted) {
        await ref.read(completedDownloadsProvider.notifier).deleteDownload(anime.id);
      }
    } catch (e) {
  
    }
  }

  Future<void> _openAnime(AnimeItem anime, WidgetRef ref) async {
    try {
      final filePath = await ref.read(completedDownloadsProvider.notifier).getFilePath(anime.id);
      if (filePath != null && context.mounted) {
        final restoreOrientations =
            AppOrientationSystemUi.orientationsFromContext(context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              filePath: filePath,
              title: '${anime.title} - Episode ${anime.episode}',
              restoreOrientationsOnExit: restoreOrientations,
            ),
          ),
        );
      }
    } catch (e) {
    
    }
  }

  Future<void> _openAnimeShow(AnimeShow animeShow, WidgetRef ref) async {
 
    Navigator.of(context).push(
      CustomPageTransitions.simpleSlide(
        AnimeDetailScreen(
          animeShowId: animeShow.id,
          initialImageUrl: animeShow.imageUrl,
          initiallyTracked: true,
        ),
        fromRight: true,
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      CustomPageTransitions.slideFromRight(
        const ProfileScreen(),
      ),
    );
  }
} 