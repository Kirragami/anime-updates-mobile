import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tomodachi.dart';
import '../models/watch_party_models.dart';
import '../providers/friends_providers.dart';
import '../providers/watch_party_provider.dart';
import '../services/auth_service.dart';
import '../services/watch_party_app_shell.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class WatchPartyLobbyScreen extends ConsumerStatefulWidget {
  const WatchPartyLobbyScreen({super.key});

  @override
  ConsumerState<WatchPartyLobbyScreen> createState() =>
      _WatchPartyLobbyScreenState();
}

class _WatchPartyLobbyScreenState extends ConsumerState<WatchPartyLobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(watchPartyProvider).isActive) {
        ref.read(watchPartyProvider.notifier).refreshState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return LoginScreen(
        destination: const WatchPartyLobbyScreen(),
      );
    }

    final partyState = ref.watch(watchPartyProvider);
    final friendsAsync = ref.watch(tomodachiNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, partyState),
              if (partyState.errorMessage != null)
                _buildMessageBanner(
                  partyState.errorMessage!,
                  isError: true,
                ),
              if (partyState.statusMessage != null)
                _buildMessageBanner(partyState.statusMessage!),
              Expanded(
                child: partyState.isActive
                    ? _buildActiveParty(context, partyState, friendsAsync)
                    : _buildInviteSection(context, friendsAsync, partyState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WatchPartySessionState partyState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Watch Party',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (partyState.isActive)
            TextButton(
              onPressed: partyState.isBusy ? null : _leaveParty,
              child: Text(
                'Leave',
                style: TextStyle(color: AppTheme.errorColor.withOpacity(0.95)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isError ? AppTheme.errorColor : AppTheme.primaryColor)
            .withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isError ? AppTheme.errorColor : AppTheme.primaryColor)
              .withOpacity(0.45),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildInviteSection(
    BuildContext context,
    AsyncValue<List<Tomodachi>> friendsAsync,
    WatchPartySessionState partyState,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          icon: Icons.groups_rounded,
          title: 'Start a watch party',
          subtitle:
              'Invite one or more friends to sync playback on your downloaded episodes.',
        ),
        const SizedBox(height: 20),
        _buildFriendInviteList(
          friendsAsync: friendsAsync,
          partyState: partyState,
        ),
      ],
    );
  }

  Widget _buildFriendInviteList({
    required AsyncValue<List<Tomodachi>> friendsAsync,
    required WatchPartySessionState partyState,
    String title = 'Invite friends',
  }) {
    final joinedMemberUsernames = partyState.partyState?.members ?? const {};
    final pendingInviteUsernames =
        partyState.partyState?.pendingInviteUsernames ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        friendsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
          error: (error, _) => _buildEmptyFriends(
            icon: Icons.error_outline,
            title: 'Could not load friends',
            subtitle: error.toString(),
          ),
          data: (friends) {
            final invitableFriends = _invitableFriends(
              friends: friends,
              joinedMemberUsernames: joinedMemberUsernames,
              pendingInviteUsernames: pendingInviteUsernames,
            );

            if (invitableFriends.isEmpty) {
              return _buildEmptyFriends(
                icon: Icons.check_circle_outline_rounded,
                title: joinedMemberUsernames.isEmpty
                    ? 'No friends yet'
                    : 'All friends invited or joined',
                subtitle: joinedMemberUsernames.isEmpty
                    ? 'Add tomodachi first, then come back to invite them.'
                    : 'Everyone available is already in the party or waiting on an invite.',
              );
            }

            return Column(
              children: invitableFriends.map((friend) {
                return _FriendInviteTile(
                  friend: friend,
                  isInviting: partyState.invitingFriendUsernames.contains(friend.username),
                  subtitle: 'Tap to invite',
                  onInvite: () => _inviteFriend(friend),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<Tomodachi> _invitableFriends({
    required List<Tomodachi> friends,
    required Set<String> joinedMemberUsernames,
    required Set<String> pendingInviteUsernames,
  }) {
    return friends
        .where(
          (friend) =>
              friend.isAccepted &&
              !joinedMemberUsernames.contains(friend.username) &&
              !pendingInviteUsernames.contains(friend.username),
        )
        .toList();
  }

  List<Tomodachi> _pendingInviteFriends({
    required List<Tomodachi> friends,
    required Set<String> pendingInviteUsernames,
  }) {
    return friends
        .where(
          (friend) => pendingInviteUsernames.contains(friend.username),
        )
        .toList();
  }

  String _memberLabel({
    required String memberUsername,
    required String? leaderUsername,
  }) {
    final currentUsername = AuthService.currentUsername;
    if (memberUsername == currentUsername) {
      return '${currentUsername ?? 'You'} (you)';
    }

    if (memberUsername == leaderUsername) {
      return '$memberUsername (leader)';
    }

    return memberUsername;
  }

  String _leaderUsername({
    required String? leaderUsername,
  }) {
    if (leaderUsername == null || leaderUsername.isEmpty) {
      return 'the leader';
    }

    if (leaderUsername == AuthService.currentUsername) {
      return AuthService.currentUsername ?? 'You';
    }

    return leaderUsername;
  }

  String _partyMemberSummary({
    required int memberCount,
    required int onlineCount,
  }) {
    final memberLabel = memberCount == 1 ? '1 member' : '$memberCount members';
    final onlineLabel =
        onlineCount == 1 ? '1 online' : '$onlineCount online';
    return '$memberLabel · $onlineLabel';
  }

  Widget _buildActiveParty(
    BuildContext context,
    WatchPartySessionState partyState,
    AsyncValue<List<Tomodachi>> friendsAsync,
  ) {
    final members = partyState.partyState?.members ?? {};
    final activeMembers = partyState.partyState?.activeMembers ?? {};
    final pendingInviteUsernames =
        partyState.partyState?.pendingInviteUsernames ?? const {};
    final friends = friendsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => <Tomodachi>[],
    );
    final pendingInviteFriends = _pendingInviteFriends(
      friends: friends,
      pendingInviteUsernames: pendingInviteUsernames,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(partyState, friends),
        const SizedBox(height: 16),
        Text(
          'Party members',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (members.isEmpty)
          _buildEmptyFriends(
            icon: Icons.hourglass_top_rounded,
            title: 'Waiting for members',
            subtitle: 'Invited friends will appear here once they join.',
          )
        else
          ...members.map((memberUsername) {
            final label = _memberLabel(
              memberUsername: memberUsername,
              leaderUsername: partyState.partyState?.leaderUsername,
            );
            final isLeader = memberUsername == partyState.partyState?.leaderUsername;
            final isOnline = activeMembers.contains(memberUsername);

            return _MemberTile(
              label: label,
              isLeader: isLeader,
              isOnline: isOnline,
            );
          }),
        if (partyState.isLeader && pendingInviteFriends.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Waiting for response',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...pendingInviteFriends.map(
            (friend) => _PendingInviteTile(
              friend: friend,
              isInviting: partyState.invitingFriendUsernames.contains(friend.username),
              onResend: () => _inviteFriend(friend),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (partyState.isLeader) ...[
          Text(
            'Ready to watch',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go back to downloaded episodes and tap an episode. Everyone in the party will follow your playback.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.download_done_rounded),
              label: const Text('Pick an episode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildFriendInviteList(
            friendsAsync: friendsAsync,
            partyState: partyState,
            title: 'Invite more friends',
          ),
        ] else ...[
          _buildInfoCard(
            icon: Icons.sync_rounded,
            title: 'Synced with the party',
            subtitle:
                'When the leader starts an episode, it will open here automatically.',
          ),
        ],
      ],
    );
  }

  Widget _buildStatusCard(
    WatchPartySessionState partyState,
    List<Tomodachi> friends,
  ) {
    final connected = partyState.isConnected;
    final memberCount = partyState.partyState?.members.length ?? 1;
    final onlineCount = partyState.partyState?.activeMembers.length ?? 0;
    final leaderUsername = partyState.partyState?.leaderUsername;
    final memberSummary = _partyMemberSummary(
      memberCount: memberCount,
      onlineCount: onlineCount,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: connected ? Colors.greenAccent : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Connected to party' : 'Reconnecting…',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  partyState.isLeader
                      ? 'You are the leader · $memberSummary'
                      : 'Leader: ${_leaderUsername(
                          leaderUsername: leaderUsername,
                        )} · $memberSummary',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (partyState.isLeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Leader',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFriends({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.45), size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteFriend(Tomodachi friend) async {
    await ref.read(watchPartyProvider.notifier).inviteFriend(
          friendUsername: friend.username,
        );
  }

  Future<void> _leaveParty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Leave watch party?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You will stop syncing playback with the party.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(watchPartyProvider.notifier).leaveParty();
    if (mounted) Navigator.of(context).pop();
  }
}

class _FriendInviteTile extends StatelessWidget {
  const _FriendInviteTile({
    required this.friend,
    required this.isInviting,
    required this.subtitle,
    required this.onInvite,
  });

  final Tomodachi friend;
  final bool isInviting;
  final String subtitle;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.25),
          child: Text(
            friend.username.isNotEmpty
                ? friend.username[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          friend.username,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        trailing: isInviting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            : Icon(Icons.send_rounded, color: AppTheme.primaryColor.withOpacity(0.9)),
        onTap: isInviting ? null : onInvite,
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.label,
    required this.isLeader,
    required this.isOnline,
  });

  final String label;
  final bool isLeader;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? Colors.greenAccent : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isLeader)
            Text(
              'Leader',
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingInviteTile extends StatelessWidget {
  const _PendingInviteTile({
    required this.friend,
    required this.isInviting,
    required this.onResend,
  });

  final Tomodachi friend;
  final bool isInviting;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: Colors.white.withOpacity(0.55),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invite sent · waiting for response',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: isInviting ? null : onResend,
            child: isInviting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : const Text('Resend'),
          ),
        ],
      ),
    );
  }
}

Future<void> showWatchPartyInviteDialog(
  BuildContext context,
  WidgetRef ref,
  WatchPartyInvitePayload payload,
) async {
  if (!payload.isValid) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Watch party invite',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${payload.leaderUsername} invited you to watch downloaded episodes together.',
          style: TextStyle(color: Colors.white.withOpacity(0.82), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(watchPartyProvider.notifier).declineInvite(payload);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(watchPartyProvider.notifier).acceptInvite(payload);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Join party'),
          ),
        ],
      );
    },
  );
}

class WatchPartyInviteLandingScreen extends ConsumerStatefulWidget {
  const WatchPartyInviteLandingScreen({
    super.key,
    required this.payload,
  });

  final WatchPartyInvitePayload payload;

  @override
  ConsumerState<WatchPartyInviteLandingScreen> createState() =>
      _WatchPartyInviteLandingScreenState();
}

class _WatchPartyInviteLandingScreenState
    extends ConsumerState<WatchPartyInviteLandingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WatchPartyAppShell.deliverInvite(widget.payload);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WatchPartyLobbyScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}
