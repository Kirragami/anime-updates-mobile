import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/download_providers.dart';
import '../providers/watch_party_provider.dart';
import '../screens/watch_party_lobby_screen.dart';
import '../services/watch_party_navigation.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';

class WatchPartyFloatingPanel extends ConsumerStatefulWidget {
  const WatchPartyFloatingPanel({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<WatchPartyFloatingPanel> createState() =>
      _WatchPartyFloatingPanelState();
}

class _WatchPartyFloatingPanelState extends ConsumerState<WatchPartyFloatingPanel>
    with SingleTickerProviderStateMixin {
  static const _iconSize = 72.0;
  static const _pillHeight = 80.0;
  static const _coinEdgeOverlap = 7.0;
  static const _leaderAvatarRadius = 14.0;
  static const _memberAvatarRadius = 12.0;
  static const _memberBubbleFill = Color(0xFF293352);
  static const _panelAnimDuration = Duration(milliseconds: 340);
  static const _rejoinButtonSize = 40.0;

  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _renderPanel = false;
  bool _hiddenForRoute = false;
  bool _rejoiningPlayback = false;
  WatchPartySessionState? _frozenPartyState;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _panelAnimDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final partyActive = ref.read(watchPartyProvider).isActive;
      if (partyActive) {
        _showPanel(
          animate: true,
          visible: !watchPartyPanelHiddenForCurrentRoute(ref),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPanel({required bool animate, bool visible = true}) {
    _frozenPartyState = ref.read(watchPartyProvider);
    setState(() {
      _renderPanel = true;
      _hiddenForRoute = !visible;
    });
    if (animate) {
      if (visible) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 0;
      }
    } else {
      _controller.value = visible ? 1 : 0;
    }
  }

  Future<void> _hidePanelForRoute() async {
    if (_hiddenForRoute && _controller.status == AnimationStatus.dismissed) {
      return;
    }
    setState(() => _hiddenForRoute = true);
    await _controller.reverse();
  }

  Future<void> _showPanelAfterRoute() async {
    if (!_renderPanel) {
      _showPanel(animate: true);
      return;
    }
    setState(() {
      _hiddenForRoute = false;
      _rejoiningPlayback = false;
    });
    await _controller.forward(from: 0);
  }

  Future<void> _hidePanelForPartyEnd() async {
    _frozenPartyState ??= ref.read(watchPartyProvider);
    await _controller.reverse();
    if (mounted) {
      setState(() {
        _renderPanel = false;
        _hiddenForRoute = false;
        _frozenPartyState = null;
      });
    }
  }

  void _syncPanelForRouteVisibility() {
    if (!ref.read(watchPartyProvider).isActive) return;
    if (watchPartyPanelHiddenForCurrentRoute(ref)) {
      _hidePanelForRoute();
    } else {
      _showPanelAfterRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(watchPartyLobbyVisibleProvider, (_, __) {
      _syncPanelForRouteVisibility();
    });
    ref.listen<bool>(watchPartyVideoPlayerVisibleProvider, (previous, next) {
      if (previous == true && next == false && _rejoiningPlayback && mounted) {
        setState(() => _rejoiningPlayback = false);
      }
      _syncPanelForRouteVisibility();
    });

    ref.listen<WatchPartySessionState>(watchPartyProvider, (previous, next) {
      final wasActive = previous?.isActive ?? false;
      if (next.isActive && !wasActive) {
        _showPanel(
          animate: true,
          visible: !watchPartyPanelHiddenForCurrentRoute(ref),
        );
      } else if (!next.isActive && wasActive) {
        _hidePanelForPartyEnd();
      } else if (_rejoiningPlayback &&
          previous?.partyState?.videoUrl != next.partyState?.videoUrl) {
        setState(() => _rejoiningPlayback = false);
      }
    });

    if (!_renderPanel && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    final liveParty = ref.watch(watchPartyProvider);
    final party = liveParty.isActive
        ? liveParty
        : (_frozenPartyState ?? liveParty);
    if (liveParty.isActive) {
      _frozenPartyState = liveParty;
    }

    if (!party.isActive && _controller.status == AnimationStatus.dismissed) {
      return const SizedBox.shrink();
    }

    final leaderUsername = party.partyState?.leaderUsername;
    final members = party.partyState?.members ?? const {};
    final title = _partyTitle(
      isLeader: party.isLeader,
      leaderUsername: leaderUsername,
    );
    final displayMembers = _displayMembers(members, leaderUsername);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showRejoinButton = !party.isLeader;
    final downloads = ref.watch(completedDownloadsProvider);
    final leaderReleaseId = party.leaderPlaybackReleaseId;
    final leaderIsWatching = party.canRejoinLeaderPlayback;
    final canRejoinPlayback = leaderIsWatching &&
        leaderReleaseId != null &&
        downloads.containsKey(leaderReleaseId);
    final showPlayButton = showRejoinButton && canRejoinPlayback;

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!,
      child: Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 14,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            height: _pillHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildPill(
                    context: context,
                    title: title,
                    displayMembers: displayMembers,
                    leaderUsername: leaderUsername,
                    showPlayButton: showPlayButton,
                    onOpenLobby: _openWatchParty,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: (_pillHeight - _iconSize) / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openWatchParty,
                    child: _buildLeadingIcon(),
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

  Future<void> _rejoinLeaderPlayback(bool canRejoin) async {
    if (_rejoiningPlayback || !canRejoin) return;

    final context = widget.navigatorKey.currentContext;
    if (context == null) return;

    setState(() => _rejoiningPlayback = true);
    try {
      await WatchPartyNavigation.rejoinLeaderPlayback(
        ref: ref,
        context: context,
      );
    } finally {
      if (mounted) {
        setState(() => _rejoiningPlayback = false);
      }
    }
  }

  Widget _buildRejoinButton() {
    return GestureDetector(
      onTap: _rejoiningPlayback
          ? null
          : () => _rejoinLeaderPlayback(true),
      child: Container(
        width: _rejoinButtonSize,
        height: _rejoinButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor.withOpacity(0.28),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.45),
          ),
        ),
        alignment: Alignment.center,
        child: _rejoiningPlayback
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor.withOpacity(0.95),
                ),
              )
            : Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.primaryColor.withOpacity(0.95),
                size: 26,
              ),
      ),
    );
  }

  void _openWatchParty() {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      CustomPageTransitions.slideUpFromBottom(
        const WatchPartyLobbyScreen(
          mode: WatchPartyLobbyMode.party,
        ),
      ),
    );
  }

  String _partyTitle({
    required bool isLeader,
    required String? leaderUsername,
  }) {
    if (isLeader) {
      return 'My watch party';
    }

    final name = leaderUsername?.trim();
    if (name == null || name.isEmpty) {
      return 'Watch party';
    }

    return "$name's watch party";
  }

  List<String> _displayMembers(Set<String> members, String? leaderUsername) {
    final others = members
        .where((username) => username != leaderUsername)
        .toList()
      ..sort();
    if (leaderUsername != null &&
        leaderUsername.isNotEmpty &&
        members.contains(leaderUsername)) {
      return [leaderUsername, ...others];
    }
    return others;
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.groups_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required String title,
    required List<String> displayMembers,
    required String? leaderUsername,
    required bool showPlayButton,
    required VoidCallback onOpenLobby,
  }) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );

    return Container(
      height: _pillHeight,
      padding: EdgeInsets.fromLTRB(
        _iconSize + 8,
        12,
        showPlayButton ? 10 : 16,
        12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(_pillHeight / 2),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenLobby,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (displayMembers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _MemberAvatarStack(
                      displayMembers: displayMembers,
                      leaderUsername: leaderUsername,
                      coinEdgeOverlap: _coinEdgeOverlap,
                      leaderRadius: _leaderAvatarRadius,
                      memberRadius: _memberAvatarRadius,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showPlayButton) ...[
            const SizedBox(width: 6),
            _buildRejoinButton(),
          ],
        ],
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  const _MemberAvatarStack({
    super.key,
    required this.displayMembers,
    required this.leaderUsername,
    required this.coinEdgeOverlap,
    required this.leaderRadius,
    required this.memberRadius,
  });

  final List<String> displayMembers;
  final String? leaderUsername;
  final double coinEdgeOverlap;
  final double leaderRadius;
  final double memberRadius;

  @override
  Widget build(BuildContext context) {
    final stackHeight = leaderRadius * 2;
    final stackWidth = displayMembers.isEmpty
        ? 0.0
        : _leftOffsetFor(displayMembers.length - 1) +
            _diameterFor(displayMembers.last);

    final paintOrder = <String>[
      ...displayMembers.where((username) => username != leaderUsername),
      if (leaderUsername != null && displayMembers.contains(leaderUsername))
        leaderUsername!,
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      height: stackHeight,
      width: stackWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          for (final username in paintOrder)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              left: _leftOffsetFor(displayMembers.indexOf(username)),
              top: _topOffsetFor(username),
              child: _MemberAvatar(
                key: ValueKey(username),
                username: username,
                isLeader: username == leaderUsername,
                leaderRadius: leaderRadius,
                memberRadius: memberRadius,
              )
                  .animate()
                  .fadeIn(duration: 220.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.72, 0.72),
                    end: const Offset(1, 1),
                    duration: 260.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
        ],
      ),
    );
  }

  double _diameterFor(String username) {
    final isLeader = username == leaderUsername;
    final radius = isLeader ? leaderRadius : memberRadius;
    return radius * 2;
  }

  double _leftOffsetFor(int index) {
    if (index <= 0) return 0;

    var offset = (leaderRadius * 2) - coinEdgeOverlap;
    for (var i = 1; i < index; i++) {
      offset += (memberRadius * 2) - coinEdgeOverlap;
    }
    return offset;
  }

  double _topOffsetFor(String username) {
    final isLeader = username == leaderUsername;
    final radius = isLeader ? leaderRadius : memberRadius;
    return (leaderRadius * 2 - radius * 2) / 2;
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    super.key,
    required this.username,
    required this.isLeader,
    required this.leaderRadius,
    required this.memberRadius,
  });

  final String username;
  final bool isLeader;
  final double leaderRadius;
  final double memberRadius;

  @override
  Widget build(BuildContext context) {
    final radius = isLeader ? leaderRadius : memberRadius;
    final initial =
        username.isNotEmpty ? username[0] : '?';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _WatchPartyFloatingPanelState._memberBubbleFill,
        border: Border.all(
          color: AppTheme.surfaceColor,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: isLeader ? 12 : 11,
            ),
      ),
    );
  }
}
