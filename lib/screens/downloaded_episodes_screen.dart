import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/completed_download.dart';
import '../providers/download_providers.dart';
import '../services/playback_progress_manager.dart';
import '../theme/app_theme.dart';
import 'anime_detail_screen.dart';
import 'video_player_screen.dart';

const double _kWideLayoutMinWidth = 600;
const double _kEpisodeTileMaxWidth = 320;
/// Locks tile geometry so corner zoom + pointing asset align with button edges.
const double _kEpisodeTileAspectRatio = 320 / 76;
const double _kEpisodeGridSpacing = 12;

class DownloadedEpisodesScreen extends ConsumerStatefulWidget {
  const DownloadedEpisodesScreen({super.key});

  @override
  ConsumerState<DownloadedEpisodesScreen> createState() => _DownloadedEpisodesScreenState();
}

class _DownloadedEpisodesScreenState extends ConsumerState<DownloadedEpisodesScreen> {
  /// Accordion (portrait) + master-detail (wide): one active show id, or null when all collapsed in portrait.
  String? _selectedShowId;

  late TextEditingController _searchController;
  Timer? _debounceTimer;

  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';

  bool _isWideLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _kWideLayoutMinWidth;

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
    final cleaned = episode.toLowerCase().replaceAll('episode', '').replaceAll('ep', '').trim();
    final match = RegExp(r'\d+').firstMatch(cleaned);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  /// Wide layout always has a concrete show when data exists.
  String? _resolveWideSelectedShowId(Map<String, List<CompletedDownload>> grouped) {
    if (grouped.isEmpty) return null;
    if (_selectedShowId != null && grouped.containsKey(_selectedShowId)) {
      return _selectedShowId;
    }
    return grouped.keys.first;
  }

  Map<String, List<CompletedDownload>> _filterGrouped(
    Map<String, List<CompletedDownload>> grouped,
  ) {
    if (_searchQuery.isEmpty) return grouped;
    return Map<String, List<CompletedDownload>>.fromEntries(
      grouped.entries.where((entry) {
        final showName = entry.value.first.showName.toLowerCase();
        return showName.contains(_searchQuery);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWideLayout(context);
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
                child: _buildCompletedDownloads(context, wide: wide),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(width: 16),
          if (!_isSearchFocused) ...[
            const Expanded(
              child: Text(
                'Downloaded Episodes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
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
          ] else ...[
            const Expanded(
              flex: 2,
              child: Text(
                'Downloaded Episodes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                height: 40,
                child: _buildSearchField(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
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
                hintText: 'Search downloaded shows',
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
    );
  }

  Widget _buildCompletedDownloads(BuildContext context, {required bool wide}) {
    final completedDownloads = ref.watch(completedDownloadsProvider);

    if (completedDownloads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download_done_rounded,
        title: 'No Downloaded Episodes',
        subtitle: 'Downloaded episodes will appear here once downloads are completed',
      );
    }

    final groupedDownloads =
        ref.read(completedDownloadsProvider.notifier).getDownloadsGroupedByShowId();
    final filteredSidebar = _filterGrouped(groupedDownloads);

    if (!wide) {
      if (filteredSidebar.isEmpty) {
        return _buildEmptyState(
          icon: _searchQuery.isEmpty ? Icons.download_done_rounded : Icons.search_off_rounded,
          title: _searchQuery.isEmpty ? 'No Downloaded Episodes' : 'No Results Found',
          subtitle: _searchQuery.isEmpty
              ? 'Downloaded episodes will appear here once downloads are completed'
              : 'Try searching with a different show name',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredSidebar.length,
        itemBuilder: (context, index) {
          final showId = filteredSidebar.keys.elementAt(index);
          final episodes = filteredSidebar[showId]!;
          final sortedEpisodes = _sortEpisodes(episodes);
          final firstEpisode = sortedEpisodes.first;
          final isExpanded = _selectedShowId == showId;

          return _buildAnimeShowCard(
            showId: showId,
            showName: firstEpisode.showName,
            episodes: sortedEpisodes,
            isExpanded: isExpanded,
            imagePathFuture: ref.read(completedDownloadsProvider.notifier).getAnimeImagePath(showId),
            onToggle: () {
              setState(() {
                if (_selectedShowId == showId) {
                  _selectedShowId = null;
                } else {
                  _selectedShowId = showId;
                }
              });
            },
          );
        },
      );
    }

    // Wide: master–detail. Search filters sidebar only; stage keeps current show.
    final stageShowId = _resolveWideSelectedShowId(groupedDownloads);
    if (stageShowId == null) {
      return _buildEmptyState(
        icon: Icons.download_done_rounded,
        title: 'No Downloaded Episodes',
        subtitle: 'Downloaded episodes will appear here once downloads are completed',
      );
    }

    final stageEpisodes = _sortEpisodes(groupedDownloads[stageShowId]!);
    final stageShowName = stageEpisodes.first.showName;
    final imagePathFuture =
        ref.read(completedDownloadsProvider.notifier).getAnimeImagePath(stageShowId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 35,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.35),
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: filteredSidebar.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No matching shows',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    itemCount: filteredSidebar.length,
                    itemBuilder: (context, index) {
                      final showId = filteredSidebar.keys.elementAt(index);
                      final eps = filteredSidebar[showId]!;
                      final sorted = _sortEpisodes(eps);
                      final name = sorted.first.showName;
                      final selected = stageShowId == showId;
                      return _buildWideSidebarTile(
                        showId: showId,
                        showName: name,
                        episodeCount: eps.length,
                        selected: selected,
                        imagePathFuture:
                            ref.read(completedDownloadsProvider.notifier).getAnimeImagePath(showId),
                        onTap: () {
                          setState(() => _selectedShowId = showId);
                        },
                      );
                    },
                  ),
          ),
        ),
        Expanded(
          flex: 65,
          child: _buildWideStage(
            context: context,
            showId: stageShowId,
            showName: stageShowName,
            episodes: stageEpisodes,
            posterFuture: imagePathFuture,
          ),
        ),
      ],
    );
  }

  Widget _buildWideSidebarTile({
    required String showId,
    required String showName,
    required int episodeCount,
    required bool selected,
    required Future<String?> imagePathFuture,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryColor.withOpacity(0.18)
                  : AppTheme.surfaceColor.withOpacity(0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primaryColor.withOpacity(0.65) : Colors.white.withOpacity(0.06),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: FutureBuilder<String?>(
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
                ),
                const SizedBox(height: 8),
                Text(
                  showName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$episodeCount ${episodeCount == 1 ? 'episode' : 'episodes'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primaryColor.withOpacity(0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideStage({
    required BuildContext context,
    required String showId,
    required String showName,
    required List<CompletedDownload> episodes,
    required Future<String?> posterFuture,
  }) {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: posterFuture,
            builder: (context, snapshot) {
              final path = snapshot.data;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: path != null && path.isNotEmpty
                    ? _BlurredPosterLayer(
                        key: ValueKey(path),
                        imagePath: path,
                      )
                    : Container(
                        key: const ValueKey('no-poster'),
                        color: AppTheme.cardColor.withOpacity(0.35),
                      ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.surfaceColor.withOpacity(0.88),
                  AppTheme.surfaceColor.withOpacity(0.94),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWideStageHeader(context, showName),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: ValueListenableBuilder(
                    valueListenable: PlaybackProgressManager().stateNotifier,
                    builder: (context, _, __) {
                      return _buildEpisodeGrid(
                        showId: showId,
                        episodes: episodes,
                        staggeredEntry: true,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideStageHeader(BuildContext context, String showName) {
    final maxRowWidth = MediaQuery.sizeOf(context).width * 0.65 - 32;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxRowWidth),
            child: Text(
              showName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeGrid({
    required String showId,
    required List<CompletedDownload> episodes,
    required bool staggeredEntry,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const tileStride = _kEpisodeTileMaxWidth + _kEpisodeGridSpacing;
        final crossAxisCount = (maxW + _kEpisodeGridSpacing) / tileStride;
        final n = crossAxisCount.floor().clamp(1, 64);
        final gridWidth = n * _kEpisodeTileMaxWidth + (n - 1) * _kEpisodeGridSpacing;

        final tiles = <Widget>[
          ...episodes.asMap().entries.map((e) {
            return _buildEpisodeItem(
              e.value,
              showId,
              index: e.key,
              staggeredEntry: staggeredEntry,
              fixedWidthTile: true,
            );
          }),
          SizedBox(
            width: _kEpisodeTileMaxWidth,
            child: _buildDownloadMoreButton(showId, forGrid: true),
          ),
        ];

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth.clamp(0.0, maxW),
            child: Wrap(
              key: ValueKey('grid-$showId'),
              spacing: _kEpisodeGridSpacing,
              runSpacing: _kEpisodeGridSpacing,
              alignment: WrapAlignment.start,
              children: tiles,
            ),
          ),
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
                          style: const TextStyle(
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
                      ...episodes.asMap().entries.map((e) {
                        return _buildEpisodeItem(
                          e.value,
                          showId,
                          index: e.key,
                          staggeredEntry: false,
                          fixedWidthTile: false,
                        );
                      }),
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

  Widget _buildEpisodeItem(
    CompletedDownload episode,
    String showId, {
    int index = 0,
    bool staggeredEntry = false,
    bool fixedWidthTile = false,
  }) {
    final lastWatchedEpisode = PlaybackProgressManager().getLastWatchedEpisode(showId);
    final isHighlightEpisode = lastWatchedEpisode == episode.episode;

    final effectDelay = staggeredEntry ? (index * 50 + 280).ms : Duration.zero;

    Widget tile = Stack(
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
                final filePath =
                    await ref.read(completedDownloadsProvider.notifier).getFilePath(episode.releaseId);
                if (!mounted || filePath == null) return;
                final nav = Navigator.of(context);
                nav.push(
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      filePath: filePath,
                      title: '${episode.showName} - Episode ${episode.episode}',
                      currentReleaseId: episode.releaseId,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Episode ${episode.episode}',
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
                )
                    .animate()
                    .fadeIn(duration: 45.ms, delay: effectDelay, curve: Curves.easeOut),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Image.asset(
                  'assets/images/pointing.png',
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                )
                    .animate()
                    .fadeIn(duration: 45.ms, delay: effectDelay, curve: Curves.easeOut),
              ),
            ),
          ),
        ],
      ],
    );

    if (fixedWidthTile) {
      tile = SizedBox(
        width: _kEpisodeTileMaxWidth,
        child: AspectRatio(
          aspectRatio: _kEpisodeTileAspectRatio,
          child: tile,
        ),
      );
    }

    if (staggeredEntry) {
      tile = tile
          .animate(key: ValueKey('${showId}_${episode.releaseId}_$index'))
          .fadeIn(duration: 280.ms, delay: (index * 50).ms, curve: Curves.easeOutCubic)
          .slideY(
            begin: 0.1,
            end: 0,
            duration: 280.ms,
            delay: (index * 50).ms,
            curve: Curves.easeOutCubic,
          );
    }

    if (fixedWidthTile) {
      return Container(
        margin: EdgeInsets.zero,
        child: tile,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: tile,
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

  Widget _buildDownloadMoreButton(String showId, {bool forGrid = false}) {
    final margin = forGrid
        ? const EdgeInsets.only(top: 0, bottom: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 16);
    return Container(
      margin: margin,
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
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Download more',
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
        ) ??
        false;
  }
}

class _BlurredPosterLayer extends StatelessWidget {
  const _BlurredPosterLayer({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.42,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Transform.scale(
          scale: 1.08,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppTheme.cardColor.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
