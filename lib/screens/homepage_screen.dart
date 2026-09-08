import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_constants.dart';
import '../models/anime_item.dart';
import '../providers/anime_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/download_providers.dart';
import '../providers/friends_providers.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/update_dialog.dart';
import 'anime_detail_screen.dart';
import 'anime_list_screen.dart';
import 'download_manager_screen.dart';
import 'downloaded_episodes_screen.dart';
import 'login_screen.dart';
import 'my_shows_screen.dart';
import 'profile_screen.dart';
import 'tomodachi_screen.dart';

class HomepageScreen extends ConsumerStatefulWidget {
  final String? fcmToken;
  const HomepageScreen({super.key, this.fcmToken});

  @override
  ConsumerState<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends ConsumerState<HomepageScreen> {
  /// Update prompt only once per cold app start, not every homepage visit.
  static bool _didCheckForUpdateThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdateOnLaunch();
    });
  }

  Future<void> _checkForUpdateOnLaunch() async {
    if (_didCheckForUpdateThisSession) return;
    _didCheckForUpdateThisSession = true;

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdate();

      // Already on the latest version: drop any leftover APK and never prompt.
      if (result['success'] == true && result['needUpdate'] != true) {
        await updateService.clearUpdateDownload();
        return;
      }

      final downloadStatus = await updateService.getUpdateDownloadStatus();
      final status = downloadStatus['status'] as String? ?? 'none';
      if (status == 'queued' || status == 'downloading' || status == 'paused') {
        return;
      }
      if (status == 'completed') {
        if (!mounted) return;
        _showUpdateDialog(isReadyToInstall: true);
        return;
      }

      if (result['success'] == true && result['needUpdate'] == true) {
        if (!mounted) return;
        _showUpdateDialog(
          downloadUrl: result['downloadUrl'] as String,
          targetVersion: result['latestVersion'] as String? ?? '',
        );
      }
    } catch (e) {}
  }

  void _showUpdateDialog({
    String? downloadUrl,
    String? targetVersion,
    bool isReadyToInstall = false,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Update dialog',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return UpdateDialog(
          downloadUrl: downloadUrl,
          targetVersion: targetVersion,
          isReadyToInstall: isReadyToInstall,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _openAnimeDetail(AnimeItem anime) {
    Navigator.of(context).push(
      CustomPageTransitions.simpleSlide(
        AnimeDetailScreen(anime: anime),
        fromRight: true,
      ),
    );
  }

  void _openMyShows() {
    Navigator.of(context).push(
      CustomPageTransitions.simpleSlide(
        const MyShowsScreen(),
        fromRight: true,
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      CustomPageTransitions.simpleFade(
        const LoginScreen(),
      ),
    );
  }

  void _openNewReleases() {
    Navigator.of(context).push(
      CustomPageTransitions.simpleSlide(
        const AnimeListScreen(),
        fromRight: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final layout = _HomepageLayout.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(layout),
                  SizedBox(height: layout.headerToContentGap),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppTheme.primaryColor,
                      onRefresh: () async {
                        ref.invalidate(animeListNotifierProvider);
                        if (isLoggedIn) {
                          ref.invalidate(trackedReleasesNotifierProvider);
                        }
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(bottom: layout.bottomPadding),
                        children: [
                          if (layout.splitTopSections) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTrackedSection(
                                    isLoggedIn,
                                    layout.forSplitColumn(isStart: true),
                                  ),
                                ),
                                SizedBox(width: layout.sectionGap),
                                Expanded(
                                  child: _buildNewReleasesSection(
                                    layout.forSplitColumn(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: layout.sectionGap),
                            _buildFriendsRecommendedSection(layout),
                          ] else ...[
                            _buildTrackedSection(isLoggedIn, layout),
                            SizedBox(height: layout.sectionGap),
                            _buildNewReleasesSection(layout),
                            SizedBox(height: layout.sectionGap),
                            _buildFriendsRecommendedSection(layout),
                          ],
                        ],
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

  Widget _buildHeader(_HomepageLayout layout) {
    if (layout.compactHeader) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          layout.horizontalPadding,
          6,
          8,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildAppTitle(layout)),
            _buildTopActions(layout),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              const Spacer(),
              _buildTopActions(layout),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            4,
            layout.horizontalPadding,
            0,
          ),
          child: _buildAppTitle(layout),
        ),
      ],
    );
  }

  Widget _buildTopActions(_HomepageLayout layout) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer(
          builder: (context, ref, child) {
            final completedDownloads = ref.watch(completedDownloadsProvider);
            final hasCompleted = completedDownloads.isNotEmpty;
            if (!hasCompleted) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Downloaded Episodes',
              icon: Icon(
                Icons.movie_creation_rounded,
                size: layout.iconSize - 4,
                color: AppTheme.textPrimary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  CustomPageTransitions.simpleSlide(
                    const DownloadedEpisodesScreen(),
                    fromRight: true,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 8),
        Consumer(
          builder: (context, ref, child) {
            final activeDownloads = ref.watch(activeDownloadsProvider);
            final activeCount = activeDownloads.length;

            return Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    size: layout.iconSize,
                    color: AppTheme.textPrimary,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      CustomPageTransitions.simpleSlide(
                        const DownloadManagerScreen(),
                        fromRight: true,
                      ),
                    );
                  },
                ),
                if (activeCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$activeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
        Consumer(
          builder: (context, ref, child) {
            final pendingCount =
                ref.watch(pendingTomodachiRequestsCountProvider);
            return Stack(
              children: [
                IconButton(
                  tooltip: 'Tomodachi',
                  icon: Icon(
                    Icons.people_alt_rounded,
                    size: layout.iconSize - 1,
                    color: AppTheme.textPrimary,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      CustomPageTransitions.simpleSlide(
                        const TomodachiScreen(),
                        fromRight: true,
                      ),
                    );
                  },
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.backgroundColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.settings_rounded,
            size: layout.iconSize - 1,
            color: AppTheme.textPrimary,
          ),
          onPressed: () {
            Navigator.of(context).push(
              CustomPageTransitions.simpleSlide(
                const ProfileScreen(),
                fromRight: true,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppTitle(_HomepageLayout layout) {
    final titleStyle = TextStyle(
      height: 0.95,
      fontSize: layout.titleFontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: layout.titleLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            'Anime',
            style: titleStyle.copyWith(color: Colors.white),
          ),
        ),
        Text(
          'Updates',
          style: titleStyle.copyWith(color: AppTheme.textPrimary),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: AppConstants.mediumAnimation)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  Widget _buildSectionHeader({
    required String title,
    required _HomepageLayout layout,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: layout.sectionInsets,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTheme.body1.copyWith(
                fontSize: layout.sectionTitleSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: layout.sectionActionSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackedSection(bool isLoggedIn, _HomepageLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Your favorites',
          layout: layout,
          actionLabel: isLoggedIn ? 'Show more' : null,
          onAction: isLoggedIn ? _openMyShows : null,
        ),
        SizedBox(height: layout.sectionHeaderGap),
        if (!isLoggedIn)
          _buildLockedCarousel(
            layout: layout,
            message: 'Login to see latest from tracked shows',
            actionLabel: 'Login',
            onAction: _openLogin,
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final trackedAsync = ref.watch(trackedReleasesNotifierProvider);
              return trackedAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _buildEmptyCarousel(
                      layout: layout,
                      message: "Really? You don't have any favorites?",
                    );
                  }
                  return _buildReleaseCarousel(
                    items.take(layout.previewItemCount).toList(),
                    layout,
                  );
                },
                loading: () => _buildCarouselLoading(layout),
                error: (_, __) => _buildEmptyCarousel(
                  layout: layout,
                  message: 'Could not load tracked releases.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(trackedReleasesNotifierProvider),
                ),
              );
            },
          ),
      ],
    )
        .animate()
        .fadeIn(duration: AppConstants.mediumAnimation)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildNewReleasesSection(_HomepageLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'New releases',
          layout: layout,
          actionLabel: 'Show more',
          onAction: _openNewReleases,
        ),
        SizedBox(height: layout.sectionHeaderGap),
        Consumer(
          builder: (context, ref, _) {
            final releasesAsync = ref.watch(animeListNotifierProvider);
            return releasesAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _buildEmptyCarousel(
                    layout: layout,
                    message: 'No new releases right now.',
                  );
                }
                return _buildReleaseCarousel(
                  items.take(layout.previewItemCount).toList(),
                  layout,
                );
              },
              loading: () => _buildCarouselLoading(layout),
              error: (_, __) => _buildEmptyCarousel(
                layout: layout,
                message: 'Could not load new releases.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(animeListNotifierProvider),
              ),
            );
          },
        ),
      ],
    )
        .animate()
        .fadeIn(
          duration: AppConstants.mediumAnimation,
          delay: const Duration(milliseconds: 80),
        )
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildFriendsRecommendedSection(_HomepageLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Tomodachis' recommendations",
          layout: layout,
        ),
        SizedBox(height: layout.sectionHeaderGap),
        _buildLockedCarousel(
          layout: layout,
          message: 'Coming soon',
        ),
      ],
    )
        .animate()
        .fadeIn(
          duration: AppConstants.mediumAnimation,
          delay: const Duration(milliseconds: 160),
        )
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildReleaseCarousel(
    List<AnimeItem> items,
    _HomepageLayout layout,
  ) {
    return SizedBox(
      height: layout.carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: layout.sectionInsets,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: layout.cardGap),
        itemBuilder: (context, index) {
          return _HomepageReleaseCard(
            anime: items[index],
            layout: layout,
            onTap: () => _openAnimeDetail(items[index]),
          )
              .animate()
              .fadeIn(
                duration: AppConstants.mediumAnimation,
                delay: Duration(milliseconds: 50 * index),
              )
              .slideX(
                begin: 0.08,
                duration: AppConstants.mediumAnimation,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(0.96, 0.96),
                duration: AppConstants.mediumAnimation,
                curve: Curves.easeOutBack,
              );
        },
      ),
    );
  }

  Widget _buildCarouselLoading(_HomepageLayout layout) {
    return SizedBox(
      height: layout.carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: layout.sectionInsets,
        itemCount: layout.skeletonCount,
        separatorBuilder: (_, __) => SizedBox(width: layout.cardGap),
        itemBuilder: (context, index) {
          return _HomepageCarouselSkeleton(layout: layout)
              .animate()
              .fadeIn(
                duration: AppConstants.shortAnimation,
                delay: Duration(milliseconds: 40 * index),
              )
              .slideX(begin: 0.04);
        },
      ),
    );
  }

  Widget _buildEmptyCarousel({
    required _HomepageLayout layout,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      height: layout.carouselHeight,
      margin: layout.sectionInsets,
      padding: EdgeInsets.all(layout.horizontalPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body2.copyWith(
                fontSize: layout.overlayMessageSize,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppConstants.shortAnimation)
        .scale(begin: const Offset(0.98, 0.98));
  }

  Widget _buildLockedCarousel({
    required _HomepageLayout layout,
    required String message,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return SizedBox(
      height: layout.carouselHeight,
      child: Stack(
        children: [
          IgnorePointer(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: layout.sectionInsets,
              itemCount: layout.skeletonCount,
              separatorBuilder: (_, __) => SizedBox(width: layout.cardGap),
              itemBuilder: (context, index) {
                return _HomepageCarouselSkeleton(
                  layout: layout,
                  showPlaceholderArt: true,
                  titleWidthFactor: 0.72 - (index % 3) * 0.08,
                );
              },
            ),
          ),
          Center(
            child: Padding(
              padding: layout.sectionInsets.add(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTheme.body1.copyWith(
                      fontSize: layout.overlayMessageSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.caption.copyWith(
                        fontSize: layout.overlayMessageSize - 2,
                        height: 1.35,
                        color: AppTheme.textSecondary.withOpacity(0.95),
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.compactHeader ? 20 : 24,
                            vertical: layout.compactHeader ? 8 : 10,
                          ),
                        ),
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: layout.sectionActionSize + 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppConstants.mediumAnimation)
        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
  }
}

class _HomepageLayout {
  final double maxContentWidth;
  final double horizontalPadding;
  final double startPadding;
  final double endPadding;
  final double titleFontSize;
  final double titleLetterSpacing;
  final double sectionTitleSize;
  final double sectionActionSize;
  final double sectionGap;
  final double sectionHeaderGap;
  final double headerToContentGap;
  final double bottomPadding;
  final double cardWidth;
  final double posterHeight;
  final double cardGap;
  final double cardTitleSize;
  final double overlayMessageSize;
  final double iconSize;
  final int skeletonCount;
  final int previewItemCount;
  final bool splitTopSections;
  final bool compactHeader;

  const _HomepageLayout({
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.startPadding,
    required this.endPadding,
    required this.titleFontSize,
    required this.titleLetterSpacing,
    required this.sectionTitleSize,
    required this.sectionActionSize,
    required this.sectionGap,
    required this.sectionHeaderGap,
    required this.headerToContentGap,
    required this.bottomPadding,
    required this.cardWidth,
    required this.posterHeight,
    required this.cardGap,
    required this.cardTitleSize,
    required this.overlayMessageSize,
    required this.iconSize,
    required this.skeletonCount,
    required this.previewItemCount,
    required this.splitTopSections,
    required this.compactHeader,
  });

  EdgeInsets get sectionInsets =>
      EdgeInsets.only(left: startPadding, right: endPadding);

  double get carouselHeight =>
      posterHeight + 10 + (cardTitleSize * 1.35 * 2) + 8;

  _HomepageLayout forSplitColumn({required bool isStart}) {
    final start = isStart ? horizontalPadding : 0.0;
    final end = isStart ? 0.0 : horizontalPadding;
    final columnWidth = (maxContentWidth - sectionGap) / 2;
    final usableWidth = columnWidth - start - end;
    final count =
        ((usableWidth + cardGap) / (cardWidth + cardGap)).floor().clamp(2, 6);

    return _HomepageLayout(
      maxContentWidth: maxContentWidth,
      horizontalPadding: horizontalPadding,
      startPadding: start,
      endPadding: end,
      titleFontSize: titleFontSize,
      titleLetterSpacing: titleLetterSpacing,
      sectionTitleSize: sectionTitleSize,
      sectionActionSize: sectionActionSize,
      sectionGap: sectionGap,
      sectionHeaderGap: sectionHeaderGap,
      headerToContentGap: headerToContentGap,
      bottomPadding: bottomPadding,
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      cardGap: cardGap,
      cardTitleSize: cardTitleSize,
      overlayMessageSize: overlayMessageSize,
      iconSize: iconSize,
      skeletonCount: count,
      previewItemCount: previewItemCount,
      splitTopSections: splitTopSections,
      compactHeader: compactHeader,
    );
  }

  factory _HomepageLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final shortest = size.shortestSide;
    final isLandscape = width > height;
    final isCompactLandscape = isLandscape && height < 500;
    final isTablet = shortest >= 600;
    final isLargeWide = width >= 1100 && shortest >= 600;
    final isTvLike = width >= 1400 || (shortest >= 800 && isLandscape);

    final double maxContentWidth;
    if (isTvLike) {
      maxContentWidth = 1280;
    } else if (isLargeWide) {
      maxContentWidth = 1120;
    } else if (width >= 900) {
      maxContentWidth = 960;
    } else {
      maxContentWidth = width;
    }

    late final double horizontalPadding;
    late final double titleFontSize;
    late final double titleLetterSpacing;
    late final double sectionTitleSize;
    late final double sectionActionSize;
    late final double sectionGap;
    late final double sectionHeaderGap;
    late final double headerToContentGap;
    late final double bottomPadding;
    late final double cardWidth;
    late final double cardGap;
    late final double cardTitleSize;
    late final double overlayMessageSize;
    late final double iconSize;
    late final int previewItemCount;
    late final bool splitTopSections;
    late final bool compactHeader;

    if (isTvLike) {
      horizontalPadding = 28;
      titleFontSize = 52;
      titleLetterSpacing = 1.8;
      sectionTitleSize = 20;
      sectionActionSize = 14;
      sectionGap = 32;
      sectionHeaderGap = 14;
      headerToContentGap = 32;
      bottomPadding = 40;
      cardWidth = 230;
      cardGap = 16;
      cardTitleSize = 14;
      overlayMessageSize = 17;
      iconSize = 34;
      previewItemCount = 10;
      splitTopSections = isLandscape && height >= 640;
      compactHeader = false;
    } else if (isLargeWide) {
      horizontalPadding = 24;
      titleFontSize = 48;
      titleLetterSpacing = 1.6;
      sectionTitleSize = 19;
      sectionActionSize = 13;
      sectionGap = 28;
      sectionHeaderGap = 14;
      headerToContentGap = 30;
      bottomPadding = 36;
      cardWidth = 210;
      cardGap = 14;
      cardTitleSize = 13;
      overlayMessageSize = 16;
      iconSize = 33;
      previewItemCount = 9;
      splitTopSections = isLandscape && height >= 600;
      compactHeader = false;
    } else if (isTablet && isLandscape) {
      horizontalPadding = 24;
      titleFontSize = isCompactLandscape ? 34 : 44;
      titleLetterSpacing = 1.5;
      sectionTitleSize = 18;
      sectionActionSize = 13;
      sectionGap = 24;
      sectionHeaderGap = 12;
      headerToContentGap = isCompactLandscape ? 16 : 28;
      bottomPadding = 32;
      cardWidth = isCompactLandscape ? 150 : 190;
      cardGap = 14;
      cardTitleSize = 12.5;
      overlayMessageSize = 15;
      iconSize = 32;
      previewItemCount = 8;
      splitTopSections = !isCompactLandscape;
      compactHeader = isCompactLandscape;
    } else if (isTablet) {
      horizontalPadding = 24;
      titleFontSize = 48;
      titleLetterSpacing = 1.6;
      sectionTitleSize = 19;
      sectionActionSize = 13;
      sectionGap = 28;
      sectionHeaderGap = 14;
      headerToContentGap = 30;
      bottomPadding = 36;
      cardWidth = 180;
      cardGap = 14;
      cardTitleSize = 13;
      overlayMessageSize = 16;
      iconSize = 32;
      previewItemCount = 7;
      splitTopSections = false;
      compactHeader = false;
    } else if (isCompactLandscape) {
      horizontalPadding = 16;
      titleFontSize = height < 380 ? 26 : 30;
      titleLetterSpacing = 1.2;
      sectionTitleSize = 15;
      sectionActionSize = 12;
      sectionGap = 18;
      sectionHeaderGap = 10;
      headerToContentGap = 16;
      bottomPadding = 24;
      cardWidth = height < 380 ? 108 : 120;
      cardGap = 10;
      cardTitleSize = 11;
      overlayMessageSize = 13;
      iconSize = 28;
      previewItemCount = 6;
      splitTopSections = false;
      compactHeader = true;
    } else if (width >= 700) {
      // Foldables / large phones in landscape-ish widths.
      horizontalPadding = 20;
      titleFontSize = 40;
      titleLetterSpacing = 1.5;
      sectionTitleSize = 17;
      sectionActionSize = 12;
      sectionGap = 24;
      sectionHeaderGap = 12;
      headerToContentGap = 26;
      bottomPadding = 32;
      cardWidth = 160;
      cardGap = 12;
      cardTitleSize = 12;
      overlayMessageSize = 15;
      iconSize = 31;
      previewItemCount = 7;
      splitTopSections = isLandscape && height >= 560;
      compactHeader = isLandscape && height < 560;
    } else {
      final narrow = width < 360;
      horizontalPadding = narrow ? 16 : 20;
      titleFontSize = narrow ? 34 : 40;
      titleLetterSpacing = 1.5;
      sectionTitleSize = 17;
      sectionActionSize = 12;
      sectionGap = 28;
      sectionHeaderGap = 12;
      headerToContentGap = 28;
      bottomPadding = 32;
      cardWidth = narrow ? 128 : 140;
      cardGap = 12;
      cardTitleSize = 12;
      overlayMessageSize = 15;
      iconSize = 31;
      previewItemCount = 5;
      splitTopSections = false;
      compactHeader = false;
    }

    // Keep poster ratio consistent with the original 140x200 cards.
    var posterHeight = cardWidth * (200 / 140);

    // On very short landscape heights, shrink posters so shelves still fit.
    if (isCompactLandscape) {
      final maxPoster = height * 0.42;
      if (posterHeight > maxPoster) {
        posterHeight = maxPoster;
      }
    }

    final usableWidth = maxContentWidth - (horizontalPadding * 2);
    final skeletonCount =
        ((usableWidth + cardGap) / (cardWidth + cardGap)).floor().clamp(3, 8);

    return _HomepageLayout(
      maxContentWidth: maxContentWidth,
      horizontalPadding: horizontalPadding,
      startPadding: horizontalPadding,
      endPadding: horizontalPadding,
      titleFontSize: titleFontSize,
      titleLetterSpacing: titleLetterSpacing,
      sectionTitleSize: sectionTitleSize,
      sectionActionSize: sectionActionSize,
      sectionGap: sectionGap,
      sectionHeaderGap: sectionHeaderGap,
      headerToContentGap: headerToContentGap,
      bottomPadding: bottomPadding,
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      cardGap: cardGap,
      cardTitleSize: cardTitleSize,
      overlayMessageSize: overlayMessageSize,
      iconSize: iconSize,
      skeletonCount: skeletonCount,
      previewItemCount: previewItemCount,
      splitTopSections: splitTopSections,
      compactHeader: compactHeader,
    );
  }
}

class _HomepageCarouselSkeleton extends StatelessWidget {
  final _HomepageLayout layout;
  final bool showPlaceholderArt;
  final double titleWidthFactor;

  const _HomepageCarouselSkeleton({
    required this.layout,
    this.showPlaceholderArt = false,
    this.titleWidthFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidth =
        layout.cardWidth * titleWidthFactor.clamp(0.45, 1.0);

    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor,
      highlightColor: AppTheme.cardColor,
      child: SizedBox(
        width: layout.cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: layout.posterHeight,
                color: AppTheme.surfaceColor,
                child: showPlaceholderArt
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_outlined,
                            size: layout.cardWidth * 0.26,
                            color: AppTheme.textSecondary.withOpacity(0.35),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: layout.cardWidth * 0.38,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: layout.cardTitleSize,
              width: titleWidth,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: layout.cardTitleSize,
              width: titleWidth * 0.62,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomepageReleaseCard extends StatelessWidget {
  final AnimeItem anime;
  final _HomepageLayout layout;
  final VoidCallback onTap;

  const _HomepageReleaseCard({
    required this.anime,
    required this.layout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: layout.posterHeight,
                  child: anime.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.surfaceColor,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.surfaceColor,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      : Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(
                            Icons.movie_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body2.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: layout.cardTitleSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
