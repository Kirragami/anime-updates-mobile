import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../models/anime_item.dart';
import '../models/download_state.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_grid_view.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as error_widgets;
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

import '../providers/download_providers.dart';
import '../app_orientation_system_ui.dart';
import 'video_player_screen.dart';

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

  
    _refreshController = RefreshController(initialRefresh: false);
    _searchController = TextEditingController();

   
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
  
        ref.read(animeListNotifierProvider.notifier).clearSearch();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String query) {

    _debounceTimer?.cancel();

 
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (query == _searchController.text) {
        if (query.isEmpty) {
       
          ref.read(animeListNotifierProvider.notifier).clearSearch();
        } else {
          ref.read(animeListNotifierProvider.notifier).searchAnime(query);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
     
          const SizedBox(width: 12),

         
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
     
              ? Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
                  .animate(curved)
           
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
      key: _refreshKey, 
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
        onDownload: (anime) async {
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
        },
        onDelete: (anime) async {
          try {
            final downloadStatus = ref.read(downloadStatusProvider(anime.id));
            
    
            if (downloadStatus.isActive) {
              await ref.read(activeDownloadsProvider.notifier).cancelDownload(anime.id);
          
            }
       
            else if (downloadStatus.isCompleted) {
              await ref.read(completedDownloadsProvider.notifier).deleteDownload(anime.id);
         
            }
          } catch (e) {
          
          }
        },
        onOpen: (anime) async {
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
                    currentReleaseId: anime.id,
                    restoreOrientationsOnExit: restoreOrientations,
                  ),
                ),
              );
            }
          } catch (e) {
         
          }
        },
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return error_widgets.CustomErrorWidget(
      message: error.toString(),
      onRetry: () {
        ref.invalidate(animeListNotifierProvider);
      },
      showRetryButton: true,
    );
  }
}
