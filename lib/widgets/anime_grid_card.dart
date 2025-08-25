import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime_item.dart';
import '../providers/anime_providers.dart';
import '../providers/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../screens/anime_detail_screen.dart';
import '../utils/page_transitions.dart';

class AnimeGridCard extends ConsumerWidget {
  final AnimeItem anime;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onOpen;
  final int index;
  final bool showTrackingIndicator;

  const AnimeGridCard({
    super.key,
    required this.anime,
    required this.onDownload,
    this.onDelete,
    this.onOpen,
    required this.index,
    this.showTrackingIndicator = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimationConfiguration.staggeredGrid(
        position: index,
        duration: AppConstants.mediumAnimation,
        columnCount: 2,
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 700),
              child: Container(
                margin: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.cardColor,
                      AppTheme.cardColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    onTap: () {
                      Navigator.of(context).push(
                        CustomPageTransitions.slideFromRight(
                          AnimeDetailScreen(anime: anime),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.smallPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                                     // Anime Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              child: _buildImageWidget(ref),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Episode Badge and Tracking Indicator Row
                          Row(
                            children: [
                              // Episode Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'EP ${anime.episode}',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Tracking Heart Button
                              Consumer(
                                builder: (context, ref, child) {
                                  final isTracked = ref.watch(animeTrackingProvider(anime));
                                  
                                  // Only show heart button when tracked
                                  if (!isTracked) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF6B9A), Color(0xFFFF3366)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF3366).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Title
                                                                                                           Text(
                              anime.title,
                            style: AppTheme.body2.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Spacer to push button to bottom
                          const Spacer(),
                          // Time Ago
                          Text(
                            _getTimeAgo(),
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                                                     // Action Buttons
                           _buildActionButtons(ref),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildImageWidget(WidgetRef ref) {
    // Use imageUrl directly from the anime item
    if (anime.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: anime.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      );
    } else {
      return _buildNoImagePlaceholder();
    }
  }



  Widget _buildErrorPlaceholder() {
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.primaryColor,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              'Failed to load',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingIndicator(WidgetRef ref) {
    // Watch the tracking state for this anime item
    final isTracked = ref.watch(animeTrackingProvider(anime));
    
    if (!isTracked) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 24, // Position above the 24px tall action buttons
      right: 0,
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.favorite,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              color: AppTheme.primaryColor,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              'No image',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
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
      child: Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(anime.releasedDate);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }

  Widget _buildActionButtons(WidgetRef ref) {
    // Watch state directly so this widget rebuilds when values change
    final isDownloading = ref.watch(
      downloadStatesNotifierProvider.select(
        (state) => state['downloading_${anime.id}'] ?? false,
      ),
    );
    final isDownloaded = ref.watch(
      downloadStatesNotifierProvider.select(
        (state) => state['downloaded_${anime.id}'] ?? false,
      ),
    );
    final downloadProgress = ref.watch(
      downloadProgressNotifierProvider.select(
        (state) => state[anime.id] ?? 0.0,
      ),
    );
    
    if (isDownloading) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 20,
            child: LinearProgressIndicator(
              value: downloadProgress,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 2),
          // Text(
          //   '${(downloadProgress * 100).toInt()}%',
          //   style: AppTheme.caption.copyWith(
          //     color: AppTheme.primaryColor,
          //     fontSize: 8,
          //   ),
          // ),
        ],
      );
    }

    if (isDownloaded) {
      return Row(
        children: [
          Expanded(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onOpen,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.textPrimary,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                                                                     onTap: onDelete,
                child: Center(
                  child: Icon(
                    Icons.delete_rounded,
                    color: AppTheme.textPrimary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: 24,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onDownload,
          child: Center(
            child: Icon(
              Icons.download_rounded,
              color: AppTheme.textPrimary,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
} 