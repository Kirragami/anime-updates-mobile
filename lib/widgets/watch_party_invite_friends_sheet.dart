import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tomodachi.dart';
import '../providers/friends_providers.dart';
import '../providers/watch_party_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'watch_party_invite_friend_tile.dart';

Future<void> showWatchPartyInviteFriendsSheet(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (dialogContext) {
      return const _WatchPartyInviteFriendsDialog();
    },
  );
}

class _WatchPartyInviteFriendsDialog extends ConsumerWidget {
  const _WatchPartyInviteFriendsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyState = ref.watch(watchPartyProvider);
    final friendsAsync = ref.watch(tomodachiNotifierProvider);
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = screenSize.height * 0.62;
    final maxWidth = screenSize.width > 520 ? 380.0 : screenSize.width * 0.88;

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Invite friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.75),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                'Send invites without leaving playback.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            if (partyState.statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    partyState.statusMessage!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (partyState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    partyState.errorMessage!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: _InviteFriendsList(
                friendsAsync: friendsAsync,
                partyState: partyState,
                onInvite: (friend) => _inviteFriend(ref, friend),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteFriend(WidgetRef ref, Tomodachi friend) async {
    await ref.read(watchPartyProvider.notifier).inviteFriend(
          friendUsername: friend.username,
        );
  }
}

class _InviteFriendsList extends StatelessWidget {
  const _InviteFriendsList({
    required this.friendsAsync,
    required this.partyState,
    required this.onInvite,
  });

  final AsyncValue<List<Tomodachi>> friendsAsync;
  final WatchPartySessionState partyState;
  final ValueChanged<Tomodachi> onInvite;

  @override
  Widget build(BuildContext context) {
    return friendsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      error: (error, _) => _EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load friends',
        subtitle: error.toString(),
      ),
      data: (friends) {
        final joinedMemberUsernames =
            partyState.partyState?.members ?? const {};
        final pendingInviteUsernames =
            partyState.partyState?.pendingInviteUsernames ?? const {};
        final currentUsername = AuthService.currentUsername;
        final acceptedFriends =
            friends.where((friend) => friend.isAccepted).toList();

        if (acceptedFriends.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_add_alt_1_rounded,
            title: 'No friends yet',
            subtitle: 'Add tomodachi first, then come back to invite them.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shrinkWrap: true,
          children: acceptedFriends.map((friend) {
            final isJoined = joinedMemberUsernames.contains(friend.username) &&
                friend.username != currentUsername;
            final isPending =
                pendingInviteUsernames.contains(friend.username);
            final isInviting =
                partyState.invitingFriendUsernames.contains(friend.username);

            return WatchPartyInviteFriendTile(
              friend: friend,
              isInviting: isInviting,
              isPending: isPending,
              isJoined: isJoined,
              compact: true,
              onInvite: () => onInvite(friend),
              onResend: () => onInvite(friend),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
