import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/anime_item.dart';
import '../providers/auth_provider.dart';
import '../providers/tracking_provider.dart';
import '../providers/anime_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_heart_button.dart';

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
    
    return Scaffold(
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
                    Icons.arrow_back_ios,
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
                    // Anime Image with Hero Animation
                    Hero(
                      tag: 'anime_image_${widget.anime.id}',
                      child: Container(
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
                              ? Image.network(
                                  widget.anime.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppTheme.surfaceColor,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                        color: AppTheme.textSecondary,
                                      ),
                                    );
                                  },
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
                            fontSize: 28,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Episode and Release Info
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Episode ${widget.anime.episode}',
                                      style: AppTheme.heading3.copyWith(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatReleaseDate(widget.anime.releasedDate),
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
                        
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        Row(
                          children: [
                            // Download Button
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, child) {
                                  // Watch state directly so this widget rebuilds when values change
                                  final isDownloading = ref.watch(
                                    downloadStatesNotifierProvider.select(
                                      (state) => state['downloading_${widget.anime.id}'] ?? false,
                                    ),
                                  );
                                  final isDownloaded = ref.watch(
                                    downloadStatesNotifierProvider.select(
                                      (state) => state['downloaded_${widget.anime.id}'] ?? false,
                                    ),
                                  );
                                  final downloadProgress = ref.watch(
                                    downloadProgressNotifierProvider.select(
                                      (state) => state[widget.anime.id] ?? 0.0,
                                    ),
                                  );
                                  
                                  if (isDownloading) {
                                    return Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Progress bar background
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceColor,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          // Progress bar fill
                                          FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: downloadProgress,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: AppTheme.primaryGradient,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                          // Percentage text
                                          Center(
                                            child: Text(
                                              '${(downloadProgress * 100).toInt()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
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
                                                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(16),
                                                onTap: () => ref.read(downloadOperationsNotifierProvider.notifier).openDownloadedFile(widget.anime),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 24,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Open',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
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
                                              colors: [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.8)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.errorColor.withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () => ref.read(downloadOperationsNotifierProvider.notifier).deleteDownload(widget.anime),
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
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => ref.read(downloadOperationsNotifierProvider.notifier).downloadAnime(widget.anime),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.download_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Download',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
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
                              // Track Button
                              Consumer(
                                builder: (context, ref, child) {
                                  final isTracked = ref.watch(animeTrackingProvider(widget.anime));
                                  final trackingNotifier = ref.read(animeTrackingProvider(widget.anime).notifier);
                                  
                                  return AnimatedHeartButton(
                                    isTracked: isTracked,
                                    onPressed: trackingNotifier.toggleTracking,
                                  );
                                }
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Additional Info Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.cardColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: AppTheme.accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'File Information',
                                    style: AppTheme.heading3.copyWith(
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('File Name', widget.anime.fileName),
                              _buildInfoRow('Release Date', DateFormat('EEEE, MMMM dd, yyyy').format(widget.anime.releasedDate)),
                              _buildInfoRow('Episode', widget.anime.episode),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
} 