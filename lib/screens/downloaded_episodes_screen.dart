import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/download_providers.dart';
import '../models/completed_download.dart';
import '../services/completed_downloads_manager.dart';
import '../services/playback_progress_manager.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import 'video_player_screen.dart';
import 'anime_detail_screen.dart';

class DownloadedEpisodesScreen extends ConsumerStatefulWidget {
  const DownloadedEpisodesScreen({super.key});

  @override
  ConsumerState<DownloadedEpisodesScreen> createState() => _DownloadedEpisodesScreenState();
}

class _DownloadedEpisodesScreenState extends ConsumerState<DownloadedEpisodesScreen> {
  final Map<String, bool> _expandedShows = {};
  late TextEditingController _searchController;
  Timer? _debounceTimer;
  
 
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchFocused = !_isSearchFocused;
      if (!_isSearchFocused) {
        _searchController.clear();
        _searchQuery = '';
        FocusScope.of(context).unfocus();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String query) {
   
    _debounceTimer?.cancel();

  
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (query == _searchController.text) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      }
    });
  }


  List<CompletedDownload> _sortEpisodes(List<CompletedDownload> episodes) {
    final sorted = List<CompletedDownload>.from(episodes);
    sorted.sort((a, b) {

      final aNum = _extractEpisodeNumber(a.episode);
      final bNum = _extractEpisodeNumber(b.episode);
      
    
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      
     
      return a.episode.compareTo(b.episode);
    });
    return sorted;
  }


  int? _extractEpisodeNumber(String episode) {
 
    final cleaned = episode.toLowerCase()
        .replaceAll('episode', '')
        .replaceAll('ep', '')
        .trim();
    

    final match = RegExp(r'\d+').firstMatch(cleaned);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
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
              _buildHeader(context),
              Expanded(
                child: _buildCompletedDownloads(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
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
          if (!_isSearchFocused) ...[
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                "Downloaded Episodes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ),
            const SizedBox(width: 12),
          ],
       
          _isSearchFocused
              ? Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    height: 40,
                    margin: const EdgeInsets.only(left: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
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
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search downloaded shows",
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
                            ),
                          ),
                  
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
                        ],
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _toggleSearch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
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
                    child: const Center(
                      child: Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCompletedDownloads() {
    return Consumer(
      builder: (context, ref, child) {
        final completedDownloads = ref.watch(completedDownloadsProvider);
        
        if (completedDownloads.isEmpty) {
          return _buildEmptyState(
            icon: Icons.download_done_rounded,
            title: 'No Downloaded Episodes',
            subtitle: 'Downloaded episodes will appear here once downloads are completed',
          );
        }

   
        final groupedDownloads = ref.read(completedDownloadsProvider.notifier).getDownloadsGroupedByShowId();
        
        
        final filteredDownloads = _searchQuery.isEmpty
            ? groupedDownloads
            : Map<String, List<CompletedDownload>>.fromEntries(
                groupedDownloads.entries.where((entry) {
                  final showName = entry.value.first.showName.toLowerCase();
                  return showName.contains(_searchQuery);
                }),
              );
        
        if (filteredDownloads.isEmpty) {
          return _buildEmptyState(
            icon: _searchQuery.isEmpty 
                ? Icons.download_done_rounded 
                : Icons.search_off_rounded,
            title: _searchQuery.isEmpty
                ? 'No Downloaded Episodes'
                : 'No Results Found',
            subtitle: _searchQuery.isEmpty
                ? 'Downloaded episodes will appear here once downloads are completed'
                : 'Try searching with a different show name',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDownloads.length,
          itemBuilder: (context, index) {
            final showId = filteredDownloads.keys.elementAt(index);
            final episodes = filteredDownloads[showId]!;
            final sortedEpisodes = _sortEpisodes(episodes);
            final firstEpisode = sortedEpisodes.first;
            final isExpanded = _expandedShows[showId] ?? false;
            
            return _buildAnimeShowCard(
              showId: showId,
              showName: firstEpisode.showName,
              episodes: sortedEpisodes,
              isExpanded: isExpanded,
              imagePathFuture: ref.read(completedDownloadsProvider.notifier).getAnimeImagePath(showId),
              onToggle: () {
                setState(() {
                  final wasExpanded = isExpanded;
                  _expandedShows.clear();
                  _expandedShows[showId] = !wasExpanded;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAnimeShowCard({
    required String showId,
    required String showName,
    required List<CompletedDownload> episodes,
    required bool isExpanded,
    required Future<String?> imagePathFuture,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
       
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
              child: Row(
          children: [
             
                  FutureBuilder<String?>(
                    future: imagePathFuture,
                    builder: (context, snapshot) {
                      final imagePath = snapshot.data;
                      return Container(
                        width: 80,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.cardColor.withOpacity(0.3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (imagePath != null && imagePath.isNotEmpty)
                              ? Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                                )
                              : _buildImagePlaceholder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
              
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          showName,
                        style: const TextStyle(
                          color: Colors.white,
                            fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                        const SizedBox(height: 8),
                      Text(
                          '${episodes.length} ${episodes.length == 1 ? 'episode' : 'episodes'}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
               
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 24,
                  ),
              ],
            ),
            ),
          ),
       
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: ValueListenableBuilder(
                valueListenable: PlaybackProgressManager().stateNotifier,
                builder: (context, _, __) {
                  return Column(
                    children: [
                      ...episodes.map((episode) => _buildEpisodeItem(episode, showId)).toList(),
                      _buildDownloadMoreButton(showId),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(CompletedDownload episode, String showId) {
    final lastWatchedReleaseId = PlaybackProgressManager().getLastWatchedReleaseId(showId);
    final lastWatchedEpisode = PlaybackProgressManager().getLastWatchedEpisode(showId);
    
    final isLastWatched = lastWatchedReleaseId == episode.releaseId;
    final isHighlightEpisode = lastWatchedEpisode == episode.episode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final filePath = await ref.read(completedDownloadsProvider.notifier).getFilePath(episode.releaseId);
                  if (filePath != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          filePath: filePath,
                          title: '${episode.showName} - Episode ${episode.episode}',
                          currentReleaseId: episode.releaseId,
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Episode ${episode.episode}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        color: AppTheme.errorColor,
                        iconSize: 22,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                        onPressed: () async {
                          final confirmed = await _showDeleteConfirmation(episode.showName, episode.episode);
                          if (confirmed && context.mounted) {
                            await ref.read(completedDownloadsProvider.notifier).deleteDownload(episode.releaseId);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isHighlightEpisode) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/gifs/zoom-effect.gif',
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/pointing.png',
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.3),
            AppTheme.primaryColor.withOpacity(0.1),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: AppTheme.primaryColor,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildDownloadMoreButton(String showId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AnimeDetailScreen(
                    animeShowId: showId,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Download more",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String showName, String episode) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Delete Download',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "$showName - Episode $episode"? This will permanently remove the downloaded file.',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }
}
