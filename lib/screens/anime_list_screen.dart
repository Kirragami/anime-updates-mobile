import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../models/anime_item.dart';
import '../providers/anime_providers.dart';
import '../providers/tracking_provider.dart';
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
  late AnimationController _placeholderAnimationController;
  late TextEditingController _searchController;
  Timer? _debounceTimer;
  final GlobalKey<SmartRefresherState> _refreshKey = GlobalKey<SmartRefresherState>();
  
  // Animated placeholder texts
  final List<String> _placeholderTexts = [
    'Search for anime...',
    'Find your favorite shows...',
    'Discover new releases...',
    'Look for specific episodes...',
    'Browse anime collection...',
  ];
  int _currentPlaceholderIndex = 0;
  late Animation<double> _scrollAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(initialRefresh: false);
    _placeholderAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _searchController = TextEditingController();
    
    // Setup scroll and fade animations
    _scrollAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _placeholderAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _placeholderAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start placeholder animation
    _startPlaceholderAnimation();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _placeholderAnimationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _startPlaceholderAnimation() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _placeholderAnimationController.forward().then((_) {
          setState(() {
            _currentPlaceholderIndex = (_currentPlaceholderIndex + 1) % _placeholderTexts.length;
          });
          _placeholderAnimationController.reset();
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Very fast debounce for more responsive search
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (query == _searchController.text) {
        ref.read(animeListNotifierProvider.notifier).searchAnime(query);
      }
    });
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
              _buildModernHeader(),
              _buildAlwaysVisibleSearchBar(),
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

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      child: Row(
        children: [
          // Modern back button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Modern title section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Newest Releases',
                  style: AppTheme.heading1.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What do you wanna watch?',
                  style: AppTheme.body1.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlwaysVisibleSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AppTheme.body1.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: '',
                border: InputBorder.none,
                prefixIcon: Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
            // Animated placeholder overlay
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 60, top: 18, bottom: 18),
                child: AnimatedBuilder(
                  animation: _placeholderAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _placeholderTexts[_currentPlaceholderIndex],
                          style: AppTheme.body1.copyWith(
                            color: AppTheme.textSecondary.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeList(List<AnimeItem> animeList) {
    return SmartRefresher(
      key: _refreshKey, // Preserve state
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