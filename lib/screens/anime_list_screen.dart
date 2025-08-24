import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
  late AnimationController _searchBarAnimationController;
  late TextEditingController _searchController;
  bool _isSearchBarVisible = false;
  Timer? _debounceTimer;
  final GlobalKey<SmartRefresherState> _refreshKey = GlobalKey<SmartRefresherState>();

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(initialRefresh: false);
    _searchBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100), // Very fast animation
      vsync: this,
    );
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchBarAnimationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _toggleSearchBar() {
    setState(() {
      _isSearchBarVisible = !_isSearchBarVisible;
      if (_isSearchBarVisible) {
        _searchBarAnimationController.forward();
      } else {
        _searchBarAnimationController.reverse();
        _searchController.clear();
        // Reset to show all items without resetting scroll position
        ref.read(animeListNotifierProvider.notifier).refresh();
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
              _buildAppBar(),
              SizeTransition(
                sizeFactor: _searchBarAnimationController,
                axisAlignment: -1.0,
                child: _buildSearchBar(),
              ),
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
              IconButton(
                onPressed: _toggleSearchBar,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isSearchBarVisible ? Icons.close_rounded : Icons.search_rounded,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: AppTheme.body1.copyWith(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search anime...',
            hintStyle: AppTheme.body2.copyWith(color: AppTheme.textSecondary),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
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