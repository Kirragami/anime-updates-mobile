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

class _AnimeListScreenState extends ConsumerState<AnimeListScreen> {
  late RefreshController _refreshController;
  late TextEditingController _searchController;
  Timer? _debounceTimer;
  final GlobalKey<SmartRefresherState> _refreshKey =
      GlobalKey<SmartRefresherState>();

  // Search focus state
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _placeholders = [
    "Search for anime",
    "Find your favorite shows",
    "Discover new releases",
    "Look for specific episodes",
    "Browse anime collection"
  ];

  int _currentPlaceholder = 0;
  late Timer _placeholderTimer;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _refreshController = RefreshController(initialRefresh: false);
    _searchController = TextEditingController();

    //change placeholder every 2 seconds;
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isSearchFocused) {
        setState(() {
          _currentPlaceholder =
              (_currentPlaceholder + 1) % _placeholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _placeholderTimer.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchFocused = !_isSearchFocused;
      if (!_isSearchFocused) {
        _searchController.clear();
        FocusScope.of(context).unfocus();
        // Clear search and return to normal browsing mode
        ref.read(animeListNotifierProvider.notifier).clearSearch();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Very fast debounce for more responsive search
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (query == _searchController.text) {
        if (query.isEmpty) {
          // Clear search when query is empty
          ref.read(animeListNotifierProvider.notifier).clearSearch();
        } else {
          ref.read(animeListNotifierProvider.notifier).searchAnime(query);
        }
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
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildModernHeader(),
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

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      // Remove background decoration to make it transparent
      child: Row(
        children: [
          // Back button and optional title
          // Title is removed when searching so the search bar shifts left
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
          if (!_isSearchFocused) ...[
            const SizedBox(width: 16),
            const Text(
              "New Releases",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          // Margin between title (when visible) and search input
          const SizedBox(width: 12),

          // Search bar
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  if (!_isSearchFocused) {
                    _toggleSearch();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor
                          .withOpacity(_isSearchFocused ? 0.6 : 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(_isSearchFocused ? 0.25 : 0.15),
                        blurRadius: _isSearchFocused ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                      if (_isSearchFocused)
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.18),
                          blurRadius: 16,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 0),
                        ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),

                      // Search input or placeholder
                      Expanded(
                        child: _isSearchFocused
                            ? TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: _placeholders[_currentPlaceholder],
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: _onSearchChanged,
                              )
                            : _buildRollingPlaceholder(),
                      ),

                      // Close button when searching
                      if (_isSearchFocused) ...[
                        GestureDetector(
                          onTap: _toggleSearch,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rolling wheel-like animated placeholder when search is not focused
  Widget _buildRollingPlaceholder() {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool isIncoming = animation.status == AnimationStatus.forward;

          final Animation<double> curved = CurvedAnimation(
            parent: isIncoming ? animation : ReverseAnimation(animation),
            curve: isIncoming ? Curves.easeOutCubic : Curves.easeInCubic,
          );

          final Animation<Offset> slide = isIncoming
              // New text comes from bottom to center
              ? Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
                  .animate(curved)
              // Old text moves from center to top
              : Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.2))
                  .animate(curved);

          final Animation<double> fade = isIncoming
              ? Tween<double>(begin: 0.0, end: 1.0).animate(curved)
              : Tween<double>(begin: 1.0, end: 0.0).animate(curved);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: Container(
          key: ValueKey<int>(_currentPlaceholder),
          alignment: Alignment.centerLeft,
          child: Text(
            _placeholders[_currentPlaceholder],
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        onDownload: (anime) => ref
            .read(downloadOperationsNotifierProvider.notifier)
            .downloadAnime(anime),
        onDelete: (anime) => ref
            .read(downloadOperationsNotifierProvider.notifier)
            .deleteDownload(anime),
        onOpen: (anime) => ref
            .read(downloadOperationsNotifierProvider.notifier)
            .openDownloadedFile(anime),
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
              child: const Icon(
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
