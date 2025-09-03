import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../providers/auth_provider.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_grid_view.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import '../widgets/loading_widget.dart';
import 'homepage_screen.dart';
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
    
    // Recheck existing downloads for tracked releases when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadOperationsNotifierProvider.notifier).recheckTrackedDownloads();
    });
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
              // Ensure download operations provider initializes to check existing files
              Consumer(
                builder: (context, ref, child) {
                  ref.watch(downloadOperationsNotifierProvider);
                  return const SizedBox.shrink();
                },
              ),
              Expanded(
                child: userAsync.when(
                  data: (user) => _buildTrackedReleasesList(),
                  loading: () => const AnimeGridSkeleton(),
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
          // Back button without background - matching anime list style
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 8,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Title section
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
                      ? 'These are your favorite: ${user.username[0].toUpperCase()}${user.username.substring(1)}-sama'
                      : 'These are your favorite:',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Profile button instead of logout
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

  Widget _buildTrackedReleasesList() {
    return Column(
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final trackedAsync = ref.watch(trackedReleasesNotifierProvider);
              return trackedAsync.when(
                data: (items) => SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  enablePullUp: false,
                  header: const WaterDropHeader(
                    waterDropColor: AppTheme.primaryColor,
                  ),
                  onRefresh: () async {
                    await ref.read(trackedReleasesNotifierProvider.notifier).refresh();
                    _refreshController.refreshCompleted();
                  },
                  child: AnimeGridView(
                    animeList: items,
                    onDownload: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).downloadAnime(anime),
                    onDelete: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).deleteDownload(anime),
                    onOpen: (anime) => ref.read(downloadOperationsNotifierProvider.notifier).openDownloadedFile(anime),
                    useTrackedProviders: true,
                  ),
                ),
                loading: () => const AnimeGridSkeleton(),
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

  // Old placeholder content removed in favor of the real list

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
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
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
          ],
        ),
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