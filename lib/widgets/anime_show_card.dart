import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime_show.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class AnimeShowCard extends ConsumerWidget {
  final AnimeShow animeShow;
  final VoidCallback onOpen;
  final int index;

  const AnimeShowCard({
    super.key,
    required this.animeShow,
    required this.onOpen,
    required this.index,
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
            constraints: const BoxConstraints(minHeight: 280), // Match original grid card height
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
              child: Stack(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      onTap: () async {
                    
                        onOpen();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.smallPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Anime Image (no Hero)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                height: 200,
                                child: _buildImageWidget(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Title
                            Text(
                              animeShow.title,
                              style: AppTheme.body2.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // NEW badge positioned to span the full card corner
                  if (animeShow.isNew())
                    Positioned(
                      top: -8,
                      right: -25,
                      child: _buildNewBadge(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    // Use imageUrl directly from the anime show
    if (animeShow.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: animeShow.imageUrl,
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
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.primaryColor,
              size: 30,
            ),
            SizedBox(height: 4),
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
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              color: AppTheme.primaryColor,
              size: 30,
            ),
            SizedBox(height: 4),
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
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildNewBadge() {
    return Transform.rotate(
      angle: 0.785398, // 45 degrees in radians
      child: Container(
        height: 20, // Fixed height for consistent sizing
        width: 100, // Increased width to reach the end of card corner
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00C9FF), // Bright cyan
              Color(0xFF92FE9D), // Light green
              Color(0xFFFF6B6B), // Coral red
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8), // Match card corner
            bottomRight: Radius.circular(8), // Match card corner
          ),
          boxShadow: [
            // Main 3D shadow - makes it appear above the card
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(4, 4),
            ),
            // Highlight shadow for 3D effect
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
            // Glow effect
            BoxShadow(
              color: const Color(0xFF00C9FF).withOpacity(0.8),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 0.6,
                height: 1.2, // Line height for better centering
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                  Shadow(
                    color: Colors.white30,
                    offset: Offset(-1, -1),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}