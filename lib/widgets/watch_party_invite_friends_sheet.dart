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
    final maxHeight = screenSize.height * 0.55;
    final maxWidth = screenSize.width > 520 ? 360.0 : screenSize.width * 0.88;

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Text(
                'Invite friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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
      error: (_, __) => const _ListMessage('Could not load friends'),
      data: (friends) {
        final joinedMemberUsernames =
            partyState.partyState?.members ?? const {};
        final pendingInviteUsernames =
            partyState.partyState?.pendingInviteUsernames ?? const {};
        final currentUsername = AuthService.currentUsername;
        final acceptedFriends =
            friends.where((friend) => friend.isAccepted).toList();

        if (acceptedFriends.isEmpty) {
          return const _ListMessage('No friends yet');
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

class _ListMessage extends StatelessWidget {
  const _ListMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 13,
        ),
      ),
    );
  }
}
