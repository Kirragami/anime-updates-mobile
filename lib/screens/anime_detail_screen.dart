import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:like_button/like_button.dart';
import '../models/anime_item.dart';
import '../models/download_state.dart';
import '../models/active_download.dart';
import '../providers/auth_provider.dart';
import '../providers/tracking_provider.dart';
import '../providers/anime_providers.dart';
import '../services/api_service.dart';
import '../providers/download_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_heart_button.dart';
import '../utils/page_transitions.dart';
import 'download_manager_screen.dart';

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final AnimeItem anime;

  const AnimeDetailScreen({
    super.key,
    required this.anime,
  });

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _formatReleaseDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
          Navigator.of(context).push(
            CustomPageTransitions.slideFromRight(const DownloadManagerScreen()),
          );
        }
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            // Custom App Bar with Hero Animation
            SliverAppBar(
              expandedHeight: 400,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Anime Image (no Hero)
                    Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          child: widget.anime.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.anime.imageUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  placeholderFadeInDuration: Duration.zero,
                                  useOldImageOnUrlChange: true,
                                  placeholder: (context, url) => Container(
                                    color: AppTheme.surfaceColor,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppTheme.surfaceColor,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 80,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.surfaceColor,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 80,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Anime Title
                        Text(
                          widget.anime.title,
                          style: AppTheme.heading1.copyWith(
                            fontSize: 20,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Episode and Release Info
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Episode ${widget.anime.episode}',
                                      style: AppTheme.body1.copyWith(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      _formatReleaseDate(
                                          widget.anime.releasedDate),
                                      style: AppTheme.body2.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons
                        Row(
                          children: [
                            // Download Button
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, child) {
                                  // Use unified download status used across the app
                                  final status = ref.watch(downloadStatusProvider(widget.anime.id));
                                  final bool isDownloading = status.isDownloading;
                                  final bool isDownloaded = status.isCompleted;
                                  final double progress = status.progress; // 0..100

                                  if (isDownloading) {
                                    return Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Progress bar background
                                            Container(color: AppTheme.surfaceColor),
                                            // Progress bar fill
                                            FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: (progress / 100).clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  gradient: AppTheme.primaryGradient,
                                                ),
                                              ),
                                            ),
                                            // Percentage text
                                            Center(
                                              child: Text(
                                                '${progress.toInt()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  if (isDownloaded) {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 56,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppTheme.primaryColor,
                                                  AppTheme.primaryColor
                                                      .withOpacity(0.8)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor
                                                      .withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(16),
                                                onTap: () async {
                                                  final success = await ref.read(completedDownloadsProvider.notifier).openFile(widget.anime.id);
                                                  // File open result - can add handling here if needed
                                                },
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 24,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Open',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          height: 56,
                                          width: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.errorColor,
                                                AppTheme.errorColor
                                                    .withOpacity(0.8)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.errorColor
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () async {
                                                final downloadStatus = ref.read(downloadStatusProvider(widget.anime.id));
                                                
                                                if (downloadStatus.isActive) {
                                                  await ref.read(activeDownloadsProvider.notifier).cancelDownload(widget.anime.id);
                                                } else if (downloadStatus.isCompleted) {
                                                  await ref.read(completedDownloadsProvider.notifier).deleteDownload(widget.anime.id);
                                                }
                                                
                                                // Download deleted
                                              },
                                              child: Center(
                                                child: Icon(
                                                  Icons.delete_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          await ref.read(activeDownloadsProvider.notifier).startDownload(
                                            releaseId: widget.anime.id,
                                            magnetUrl: widget.anime.downloadUrl,
                                            fileName: widget.anime.fileName,
                                            showName: widget.anime.title,
                                            episode: widget.anime.episode,
                                          );
                                          // Download started
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: const Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.download_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Download',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            if (isLoggedIn) ...[
                              const SizedBox(width: 16),
                              // Track Button (LikeButton)
                              Consumer(builder: (context, ref, child) {
                                final isTracked = ref
                                    .watch(animeTrackingProvider(widget.anime));
                                final trackingNotifier = ref.read(
                                    animeTrackingProvider(widget.anime)
                                        .notifier);

                                return LikeButton(
                                  size: 50,
                                  isLiked: isTracked,
                                  circleColor: CircleColor(
                                    start: AppTheme.errorColor.withOpacity(0.3),
                                    end: AppTheme.errorColor.withOpacity(0.6),
                                  ),
                                  bubblesColor: BubblesColor(
                                    dotPrimaryColor: AppTheme.errorColor,
                                    dotSecondaryColor:
                                        AppTheme.errorColor.withOpacity(0.8),
                                  ),
                                  likeBuilder: (bool liked) {
                                    return Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.06),
                                        ),
                                      ),
                                      child: Icon(
                                        liked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: liked
                                            ? AppTheme.errorColor
                                            : AppTheme.textSecondary,
                                      ),
                                    );
                                  },
                                  onTap: (bool liked) async {
                                    final willBeTracked = !liked;
                                    await trackingNotifier.toggleTracking();
                                    if (!mounted) return liked;
                                    return willBeTracked;
                                  },
                                );
                              }),
                            ],
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Episodes Section
                        _buildEpisodesSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.body2.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.body1.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesHeader(List<AnimeItem> episodes) {
    return const Text(
      'All Episodes',
      style: AppTheme.heading3,
    );
  }

  Widget _buildEpisodesSection() {
    return FutureBuilder<List<AnimeItem>>(
      future: ApiService().fetchAnimeShowEpisodes(widget.anime.animeShowId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEpisodesHeader([]),
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEpisodesHeader([]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load episodes',
                      style: AppTheme.heading3.copyWith(
                        color: AppTheme.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTheme.body2.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEpisodesHeader([]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.movie_outlined,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No episodes available',
                      style: AppTheme.heading3.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final episodes = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEpisodesHeader(episodes),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: episodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return _buildEpisodeItem(episode);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEpisodeItem(AnimeItem episode) {
    return Consumer(
      builder: (context, ref, child) {
        final downloadStatus = ref.watch(downloadStatusProvider(episode.id));
        
        final isDownloading = downloadStatus.isDownloading;
        final isPaused = downloadStatus.isPaused;
        final isDownloaded = downloadStatus.isCompleted;
        final progress = downloadStatus.progress;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              episode.title,
              style: AppTheme.heading3.copyWith(
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Episode ${episode.episode} • ${_formatReleaseDate(episode.releasedDate)}',
                style: AppTheme.body2.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            trailing: SizedBox(
              width: 120,
              height: 40,
              child: isDownloading || isPaused
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Progress indicator
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (progress / 100.0).clamp(0.0, 1.0),
                                strokeWidth: 3,
                                backgroundColor: AppTheme.surfaceColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                '${progress.toInt()}%',
                                style: AppTheme.body2.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Pause/Resume button
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: isDownloading
                                ? const Icon(
                                    Icons.pause_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                            onPressed: () async {
                              try {
                                if (isDownloading) {
                                  await ref.read(activeDownloadsProvider.notifier).pauseDownload(episode.id);
                                } else if (isPaused) {
                                  await ref.read(activeDownloadsProvider.notifier).resumeDownload(episode.id);
                                }
                              } catch (e) {
                                // Error handling download pause/resume
                              }
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete button
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.errorColor,
                                AppTheme.errorColor.withOpacity(0.8)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () async {
                              try {
                                if (downloadStatus.isActive) {
                                  await ref.read(activeDownloadsProvider.notifier).cancelDownload(episode.id);
                                } else if (downloadStatus.isCompleted) {
                                  await ref.read(completedDownloadsProvider.notifier).deleteDownload(episode.id);
                                }
                                // Download deleted
                              } catch (e) {
                                // Error deleting download
                              }
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    )
                  : isDownloaded
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () async {
                              try {
                                final success = await ref.read(completedDownloadsProvider.notifier).openFile(episode.id);
                                if (!success) {
                                  // Failed to open file
                                }
                              } catch (e) {
                                // Error opening file
                              }
                            },
                            padding: EdgeInsets.zero,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(activeDownloadsProvider.notifier).startDownload(
                                  releaseId: episode.id,
                                  magnetUrl: episode.downloadUrl,
                                  fileName: episode.fileName,
                                  showName: episode.title,
                                  episode: episode.episode,
                                );
                              } catch (e) {
                                // Download failed
                              }
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
            ),
          ),
        );
      },
    );
  }
}
