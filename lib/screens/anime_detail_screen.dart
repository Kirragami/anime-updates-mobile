import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:like_button/like_button.dart';
import 'package:shimmer/shimmer.dart';
import '../models/anime_item.dart';
import '../providers/auth_provider.dart';
import '../providers/anime_providers.dart';
import '../services/api_service.dart';
import '../services/services.dart';
import '../services/tracking_service.dart';
import '../providers/download_providers.dart';
import '../theme/app_theme.dart';
import '../app_orientation_system_ui.dart';
import 'video_player_screen.dart';

/// Typography and spacing tuned for phone/tablet portrait vs split wide layout.
class _DetailTypography {
  const _DetailTypography({
    required this.titleFontSize,
    required this.titleHeight,
    required this.sectionTitleSize,
    required this.sectionTitleLetterSpacing,
    required this.episodeTitleSize,
    required this.episodeMetaSize,
    required this.progressLabelSize,
    required this.sectionHeadingGap,
    required this.episodeListGap,
    required this.episodeTilePaddingH,
    required this.episodeTilePaddingV,
    required this.trailingBandHeight,
    required this.actionIconExtent,
    required this.actionIconGlyphSize,
    required this.progressRingSize,
    required this.gridChildAspectRatio,
    required this.shimmerEpisodeHeight,
    required this.titleSectionPaddingH,
    required this.titleSectionPaddingV,
    required this.wideTitleTopPadding,
    required this.trailingBandWidth,
  });

  final double titleFontSize;
  final double titleHeight;
  final double sectionTitleSize;
  final double sectionTitleLetterSpacing;
  final double episodeTitleSize;
  final double episodeMetaSize;
  final double progressLabelSize;
  final double sectionHeadingGap;
  final double episodeListGap;
  final double episodeTilePaddingH;
  final double episodeTilePaddingV;
  final double trailingBandHeight;
  final double actionIconExtent;
  final double actionIconGlyphSize;
  final double progressRingSize;
  final double gridChildAspectRatio;
  final double shimmerEpisodeHeight;
  final double titleSectionPaddingH;
  final double titleSectionPaddingV;
  final double wideTitleTopPadding;
  final double trailingBandWidth;

  factory _DetailTypography.forLayout(
    BuildContext context, {
    required bool wideLayout,
    required double layoutWidth,
  }) {
    final mq = MediaQuery.of(context);
    final double shortest = mq.size.shortestSide;
    final double rhsApprox = wideLayout ? layoutWidth * 0.65 : layoutWidth;
    final bool compactWide = wideLayout && rhsApprox < 420;
    final bool largeWide = wideLayout && layoutWidth >= 1024;
    final bool tabletPortrait = !wideLayout && layoutWidth >= 600;
    final bool narrowPortrait = !wideLayout && layoutWidth < 360;

    if (wideLayout) {
      if (largeWide) {
        return _DetailTypography(
          titleFontSize: 24,
          titleHeight: 1.28,
          sectionTitleSize: 20,
          sectionTitleLetterSpacing: -0.2,
          episodeTitleSize: 14,
          episodeMetaSize: 12,
          progressLabelSize: 9,
          sectionHeadingGap: 14,
          episodeListGap: 10,
          episodeTilePaddingH: 18,
          episodeTilePaddingV: 4,
          trailingBandHeight: 36,
          actionIconExtent: 34,
          actionIconGlyphSize: 17,
          progressRingSize: 30,
          gridChildAspectRatio: 4.1,
          shimmerEpisodeHeight: 58,
          titleSectionPaddingH: 24,
          titleSectionPaddingV: 14,
          wideTitleTopPadding: 48,
          trailingBandWidth: 124,
        );
      }
      if (compactWide || shortest < 380) {
        return _DetailTypography(
          titleFontSize: 17,
          titleHeight: 1.22,
          sectionTitleSize: 16,
          sectionTitleLetterSpacing: -0.1,
          episodeTitleSize: 12.5,
          episodeMetaSize: 11,
          progressLabelSize: 8,
          sectionHeadingGap: 12,
          episodeListGap: 8,
          episodeTilePaddingH: 12,
          episodeTilePaddingV: 2,
          trailingBandHeight: 32,
          actionIconExtent: 30,
          actionIconGlyphSize: 16,
          progressRingSize: 26,
          gridChildAspectRatio: 4.4,
          shimmerEpisodeHeight: 52,
          titleSectionPaddingH: 16,
          titleSectionPaddingV: 10,
          wideTitleTopPadding: mq.padding.top + 8,
          trailingBandWidth: 104,
        );
      }
      return _DetailTypography(
        titleFontSize: 20,
        titleHeight: 1.26,
        sectionTitleSize: 18,
        sectionTitleLetterSpacing: -0.15,
        episodeTitleSize: 13.5,
        episodeMetaSize: 11.5,
        progressLabelSize: 8.5,
        sectionHeadingGap: 13,
        episodeListGap: 9,
        episodeTilePaddingH: 16,
        episodeTilePaddingV: 3,
        trailingBandHeight: 34,
        actionIconExtent: 32,
        actionIconGlyphSize: 17,
        progressRingSize: 28,
        gridChildAspectRatio: 4.2,
        shimmerEpisodeHeight: 54,
        titleSectionPaddingH: 20,
        titleSectionPaddingV: 12,
        wideTitleTopPadding: 44,
        trailingBandWidth: 116,
      );
    }

    if (tabletPortrait) {
      return _DetailTypography(
        titleFontSize: 23,
        titleHeight: 1.28,
        sectionTitleSize: 19,
        sectionTitleLetterSpacing: -0.2,
        episodeTitleSize: 14,
        episodeMetaSize: 12,
        progressLabelSize: 9,
        sectionHeadingGap: 14,
        episodeListGap: 10,
        episodeTilePaddingH: 18,
        episodeTilePaddingV: 4,
        trailingBandHeight: 36,
        actionIconExtent: 34,
        actionIconGlyphSize: 17,
        progressRingSize: 30,
        gridChildAspectRatio: 4.0,
        shimmerEpisodeHeight: 58,
        titleSectionPaddingH: 24,
        titleSectionPaddingV: 14,
        wideTitleTopPadding: 48,
        trailingBandWidth: 122,
      );
    }
    if (narrowPortrait) {
      return _DetailTypography(
        titleFontSize: 18,
        titleHeight: 1.24,
        sectionTitleSize: 16,
        sectionTitleLetterSpacing: -0.1,
        episodeTitleSize: 12.5,
        episodeMetaSize: 11,
        progressLabelSize: 8,
        sectionHeadingGap: 12,
        episodeListGap: 8,
        episodeTilePaddingH: 14,
        episodeTilePaddingV: 2,
        trailingBandHeight: 32,
        actionIconExtent: 30,
        actionIconGlyphSize: 16,
        progressRingSize: 26,
        gridChildAspectRatio: 4.2,
        shimmerEpisodeHeight: 52,
        titleSectionPaddingH: 16,
        titleSectionPaddingV: 10,
        wideTitleTopPadding: 44,
        trailingBandWidth: 104,
      );
    }

    return _DetailTypography(
      titleFontSize: 21,
      titleHeight: 1.26,
      sectionTitleSize: 17.5,
      sectionTitleLetterSpacing: -0.15,
      episodeTitleSize: 13.5,
      episodeMetaSize: 11.5,
      progressLabelSize: 8.5,
      sectionHeadingGap: 13,
      episodeListGap: 9,
      episodeTilePaddingH: 16,
      episodeTilePaddingV: 3,
      trailingBandHeight: 34,
      actionIconExtent: 32,
      actionIconGlyphSize: 17,
      progressRingSize: 28,
      gridChildAspectRatio: 4.0,
      shimmerEpisodeHeight: 54,
      titleSectionPaddingH: 20,
      titleSectionPaddingV: 12,
      wideTitleTopPadding: 44,
      trailingBandWidth: 116,
    );
  }
}

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final AnimeItem? anime;
  final String? animeShowId;
  final String? initialImageUrl;
  final bool initiallyTracked;

  const AnimeDetailScreen({
    super.key,
    this.anime,
    this.animeShowId,
    this.initialImageUrl,
    this.initiallyTracked = false,
  }) : assert(anime != null || animeShowId != null,
            "Either anime or animeShowId must be provided");

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimeItem? _animeItem;
  bool _isLoadingFromShowId = false;
  late final String _showId;
  late final Future<List<AnimeItem>> _episodesFuture;
  bool _showIsTracked = false;

  @override
  void initState() {
    super.initState();
    if (widget.anime != null) {
      _animeItem = widget.anime;
    }

    _showId = widget.animeShowId ?? widget.anime?.animeShowId ?? '';
    _showIsTracked = widget.anime?.tracked ?? widget.initiallyTracked;
    _episodesFuture = _showId.isNotEmpty
        ? ApiService().fetchAnimeShowEpisodes(_showId)
        : Future.value(const <AnimeItem>[]);

    if (widget.anime == null && widget.animeShowId != null) {
      _isLoadingFromShowId = true;
      _fetchInitialAnimeItem();
    }

    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _fetchInitialAnimeItem() async {
    try {
      final episodes = await _episodesFuture;
      if (episodes.isNotEmpty) {
        setState(() {
          _animeItem = episodes.first;
          _isLoadingFromShowId = false;
        });
      } else {
        setState(() => _isLoadingFromShowId = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load anime details: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
        setState(() => _isLoadingFromShowId = false);
      } else {
        _isLoadingFromShowId = false;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _makeTrackingApiCall(
      String animeShowId, bool wasTracked, WidgetRef ref) async {
    try {
      final trackingService = TrackingService();
      final result = wasTracked
          ? await trackingService.untrackAnime(animeShowId)
          : await trackingService.trackAnime(animeShowId);
      if (!result['success']) {
        ref
            .read(animeListNotifierProvider.notifier)
            .updateTrackingForShowId(animeShowId, wasTracked);
        if (mounted) _setShowTracked(wasTracked);
      }
    } catch (e) {
      ref
          .read(animeListNotifierProvider.notifier)
          .updateTrackingForShowId(animeShowId, wasTracked);
      if (mounted) _setShowTracked(wasTracked);
    }
  }

  String _formatReleaseDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) return '${difference.inMinutes} minutes ago';
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String get _imageUrl {
    if (_animeItem?.imageUrl.isNotEmpty == true) return _animeItem!.imageUrl;
    if (widget.initialImageUrl?.isNotEmpty == true)
      return widget.initialImageUrl!;
    return '';
  }

  Widget _buildPosterImage({BoxFit fit = BoxFit.cover}) {
    final url = _imageUrl;
    if (url.isEmpty) {
      return Container(
        color: AppTheme.surfaceColor,
        child: const Icon(Icons.image_not_supported,
            size: 60, color: AppTheme.textSecondary),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => Container(color: AppTheme.surfaceColor),
      errorWidget: (_, __, ___) => Container(
        color: AppTheme.surfaceColor,
        child: const Icon(Icons.image_not_supported,
            size: 60, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildBackButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  bool _resolveShowTracked(WidgetRef ref) {
    if (_showIsTracked) return true;
    if (_showId.isEmpty) return _animeItem?.tracked ?? false;

    final trackedInReleases = ref.watch(animeListNotifierProvider).maybeWhen(
          data: (list) =>
              list.any((item) => item.animeShowId == _showId && item.tracked),
          orElse: () => false,
        );
    if (trackedInReleases) return true;

    final trackedInShows = ref.watch(trackedShowsNotifierProvider).maybeWhen(
          data: (shows) => shows.any((show) => show.id == _showId),
          orElse: () => false,
        );
    if (trackedInShows) return true;

    return _animeItem?.tracked ?? widget.initiallyTracked;
  }

  void _setShowTracked(bool tracked) {
    if (_showIsTracked == tracked) return;
    setState(() => _showIsTracked = tracked);
  }

  Widget _buildLikeButton() {
    return Consumer(builder: (context, ref, _) {
      final isTracked = _resolveShowTracked(ref);
      return LikeButton(
        size: 48,
        isLiked: isTracked,
        circleColor: CircleColor(
          start: AppTheme.errorColor.withOpacity(0.3),
          end: AppTheme.errorColor.withOpacity(0.6),
        ),
        bubblesColor: BubblesColor(
          dotPrimaryColor: AppTheme.errorColor,
          dotSecondaryColor: AppTheme.errorColor.withOpacity(0.8),
        ),
        likeBuilder: (bool liked) => Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: liked ? AppTheme.errorColor : AppTheme.textSecondary,
          ),
        ),
        onTap: (bool liked) async {
          final willBeTracked = !liked;
          _setShowTracked(willBeTracked);
          ref
              .read(animeListNotifierProvider.notifier)
              .updateTrackingForShowId(_animeItem!.animeShowId, willBeTracked);
          _makeTrackingApiCall(_animeItem!.animeShowId, liked, ref);
          if (!mounted) return liked;
          return willBeTracked;
        },
      );
    });
  }

  Widget _buildTitleRow(bool isLoggedIn, _DetailTypography t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _animeItem?.title ?? '',
            style: AppTheme.heading1.copyWith(
              fontSize: t.titleFontSize,
              height: t.titleHeight,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (isLoggedIn) ...[const SizedBox(width: 12), _buildLikeButton()],
      ],
    );
  }

  Widget _buildPortraitLayout(bool isLoggedIn, double layoutWidth) {
    final t = _DetailTypography.forLayout(context,
        wideLayout: false, layoutWidth: layoutWidth);
    const double heroH = 300;
    const double posterH = 220;
    const double posterW = 150;
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: heroH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter:
                                    ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                                child: Transform.scale(
                                  scale: 1.08,
                                  alignment: Alignment.center,
                                  child: _buildPosterImage(),
                                ),
                              ),
                              Container(color: Colors.black.withOpacity(0.52)),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.backgroundColor.withOpacity(0.9)
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -(posterH * 0.18),
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: posterW,
                            height: posterH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.55),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildPosterImage(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(top: 0, left: 0, child: _buildBackButton()),
                    ],
                  ),
                ),
                const SizedBox(height: posterH * 0.22),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: t.titleSectionPaddingH,
                      vertical: t.titleSectionPaddingV),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildTitleRow(isLoggedIn, t),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: t.titleSectionPaddingH),
                  child:
                      const Divider(color: AppTheme.surfaceColor, height: 20),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: t.titleSectionPaddingH),
            sliver: SliverToBoxAdapter(
              child: _buildEpisodesSection(twoColumnGrid: false, typography: t),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: bottomSafe > 0 ? bottomSafe + 12 : 36),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isLoggedIn, double totalWidth) {
    final t = _DetailTypography.forLayout(context,
        wideLayout: true, layoutWidth: totalWidth);
    final double leftW = totalWidth * 0.35;
    final bool use2Col = totalWidth > 1024;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: leftW,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPosterImage(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      AppTheme.backgroundColor.withOpacity(0.65)
                    ],
                    stops: const [0.65, 1.0],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(top: 0, left: 0, child: _buildBackButton()),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.titleSectionPaddingH,
                      t.wideTitleTopPadding,
                      t.titleSectionPaddingH,
                      14,
                    ),
                    child: _buildTitleRow(isLoggedIn, t),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: t.titleSectionPaddingH),
                  child: const Divider(color: AppTheme.surfaceColor, height: 8),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      t.titleSectionPaddingH,
                      12,
                      t.titleSectionPaddingH,
                      28,
                    ),
                    child: _buildEpisodesSection(
                        twoColumnGrid: use2Col, typography: t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    if (_isLoadingFromShowId) {
      return Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
                  child: Shimmer.fromColors(
                    baseColor: AppTheme.surfaceColor,
                    highlightColor: AppTheme.cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 150,
                            height: 220,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 22,
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: 110,
                          height: 18,
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 16),
                        for (int i = 0; i < 5; i++) ...[
                          Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(top: 0, left: 0, child: _buildBackButton()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 768 ||
                MediaQuery.of(context).orientation == Orientation.landscape;
            return isTwoColumn
                ? _buildWideLayout(isLoggedIn, constraints.maxWidth)
                : _buildPortraitLayout(isLoggedIn, constraints.maxWidth);
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesSection({
    bool twoColumnGrid = false,
    required _DetailTypography typography,
  }) {
    final t = typography;
    return FutureBuilder<List<AnimeItem>>(
      future: _episodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: AppTheme.surfaceColor,
                highlightColor: AppTheme.cardColor,
                child: Column(
                  children: List.generate(
                      5,
                      (_) => Padding(
                            padding: EdgeInsets.only(bottom: t.episodeListGap),
                            child: Container(
                              height: t.shimmerEpisodeHeight,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.15),
                                    width: 1),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: t.episodeTilePaddingH,
                                    vertical: t.episodeTilePaddingV + 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 110,
                                            height: t.episodeTitleSize + 1,
                                            decoration: BoxDecoration(
                                                color: AppTheme.cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                          ),
                                          SizedBox(
                                              height: t.episodeMetaSize > 11
                                                  ? 6
                                                  : 5),
                                          Container(
                                            width: 72,
                                            height: t.episodeMetaSize,
                                            decoration: BoxDecoration(
                                                color: AppTheme.cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: t.actionIconExtent,
                                      height: t.actionIconExtent,
                                      decoration: BoxDecoration(
                                          color: AppTheme.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildEpisodeMessage(
            typography: t,
            icon: Icons.error_outline,
            iconColor: AppTheme.errorColor,
            text: 'Failed to load episodes',
            subtitle: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEpisodeMessage(
            typography: t,
            icon: Icons.movie_outlined,
            iconColor: AppTheme.textSecondary,
            text: 'No episodes available',
          );
        }

        final episodes = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (twoColumnGrid)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: t.gridChildAspectRatio,
                ),
                itemCount: episodes.length,
                itemBuilder: (_, i) => _buildEpisodeItem(episodes[i], t),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: episodes.length,
                separatorBuilder: (_, __) => SizedBox(height: t.episodeListGap),
                itemBuilder: (_, i) => _buildEpisodeItem(episodes[i], t),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEpisodeMessage({
    required _DetailTypography typography,
    required IconData icon,
    required Color iconColor,
    required String text,
    String? subtitle,
  }) {
    final t = typography;
    return Container(
      padding: EdgeInsets.all(t.titleSectionPaddingH + 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: iconColor,
              size: 40 + (t.sectionTitleSize - 17).clamp(0, 6)),
          SizedBox(height: t.sectionHeadingGap),
          Text(
            text,
            style: AppTheme.heading3.copyWith(
              fontSize: t.sectionTitleSize,
              color: iconColor,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTheme.body2.copyWith(
                fontSize: t.episodeMetaSize,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(AnimeItem episode, _DetailTypography t) {
    return Consumer(
      builder: (context, ref, _) {
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
                color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
          ),
          child: ListTile(
            minVerticalPadding: 0,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
            contentPadding: EdgeInsets.symmetric(
                horizontal: t.episodeTilePaddingH,
                vertical: t.episodeTilePaddingV),
            title: Text(
              'Episode ${episode.episode}',
              style: AppTheme.heading3.copyWith(
                fontSize: t.episodeTitleSize,
                fontWeight: FontWeight.w600,
                height: 1.12,
                letterSpacing: -0.08,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatReleaseDate(episode.releasedDate),
                style: AppTheme.body2.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: t.episodeMetaSize,
                  height: 1.2,
                ),
              ),
            ),
            trailing: SizedBox(
              width: t.trailingBandWidth,
              height: t.trailingBandHeight,
              child: isDownloading || isPaused
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: t.progressRingSize,
                          height: t.progressRingSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (progress / 100.0).clamp(0.0, 1.0),
                                strokeWidth: t.progressRingSize >= 28 ? 3 : 2.5,
                                backgroundColor: AppTheme.surfaceColor,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor),
                              ),
                              Text(
                                '${progress.toInt()}%',
                                style: AppTheme.body2.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: t.progressLabelSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: t.trailingBandWidth < 110 ? 6 : 8),
                        _actionIcon(
                          gradient: AppTheme.primaryGradient,
                          icon: isDownloading
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          extent: t.actionIconExtent,
                          iconSize: t.actionIconGlyphSize,
                          onTap: () async {
                            if (isDownloading) {
                              await ref
                                  .read(activeDownloadsProvider.notifier)
                                  .pauseDownload(episode.id);
                            } else if (isPaused) {
                              await ref
                                  .read(activeDownloadsProvider.notifier)
                                  .resumeDownload(episode.id);
                            }
                          },
                        ),
                        SizedBox(width: t.trailingBandWidth < 110 ? 4 : 6),
                        _actionIcon(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.errorColor,
                              AppTheme.errorColor.withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          icon: Icons.delete_rounded,
                          extent: t.actionIconExtent,
                          iconSize: t.actionIconGlyphSize,
                          onTap: () async {
                            if (downloadStatus.isActive) {
                              await ref
                                  .read(activeDownloadsProvider.notifier)
                                  .cancelDownload(episode.id);
                            } else if (downloadStatus.isCompleted) {
                              await ref
                                  .read(completedDownloadsProvider.notifier)
                                  .deleteDownload(episode.id);
                            }
                          },
                        ),
                      ],
                    )
                  : isDownloaded
                      ? _actionIcon(
                          gradient: AppTheme.primaryGradient,
                          icon: Icons.play_arrow_rounded,
                          extent: t.actionIconExtent,
                          iconSize: t.actionIconGlyphSize,
                          onTap: () async {
                            final filePath = await ref
                                .read(completedDownloadsProvider.notifier)
                                .getFilePath(episode.id);
                            if (filePath != null && context.mounted) {
                              final restoreOrientations = AppOrientationSystemUi
                                  .orientationsFromContext(
                                context,
                              );
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  filePath: filePath,
                                  title:
                                      '${episode.title} - Episode ${episode.episode}',
                                  currentReleaseId: episode.id,
                                  restoreOrientationsOnExit:
                                      restoreOrientations,
                                ),
                              ));
                            }
                          },
                        )
                      : _actionIcon(
                          gradient: AppTheme.primaryGradient,
                          icon: Icons.download_rounded,
                          extent: t.actionIconExtent,
                          iconSize: t.actionIconGlyphSize,
                          onTap: () async {
                            final isTracked = _resolveShowTracked(ref);
                            await ref
                                .read(activeDownloadsProvider.notifier)
                                .startDownload(
                                  releaseId: episode.id,
                                  magnetUrl: episode.downloadUrl,
                                  fileName: episode.fileName,
                                  showName: episode.title,
                                  episode: episode.episode,
                                  animeShowId: episode.animeShowId,
                                  imageUrl: episode.imageUrl,
                                  isTracked: isTracked,
                                );
                            if (!isTracked &&
                                ref
                                    .read(userPreferencesServiceProvider)
                                    .autoTrackOnDownload) {
                              _setShowTracked(true);
                            }
                          },
                        ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionIcon({
    required Gradient gradient,
    required IconData icon,
    required VoidCallback onTap,
    double extent = 36,
    double iconSize = 18,
  }) {
    final r = extent >= 34 ? 8.0 : 7.0;
    return Container(
      width: extent,
      height: extent,
      decoration: BoxDecoration(
          gradient: gradient, borderRadius: BorderRadius.circular(r)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
