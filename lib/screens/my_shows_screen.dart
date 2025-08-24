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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Shows',
                  style: AppTheme.heading2.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user != null 
                      ? 'These are your favorite, ${user.username[0].toUpperCase()}${user.username.substring(1)}-sama'
                      : 'These are your favorite,',
                  style: AppTheme.body2.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.errorColor,
                size: 24,
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
              child: Icon(
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

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: AppTheme.body1.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTheme.body1.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(authNotifierProvider).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    CustomPageTransitions.elasticBounce(const HomepageScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
} 