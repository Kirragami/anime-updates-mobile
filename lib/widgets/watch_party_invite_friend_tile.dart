import 'package:flutter/material.dart';

import '../models/tomodachi.dart';
import '../theme/app_theme.dart';

class WatchPartyInviteFriendTile extends StatelessWidget {
  const WatchPartyInviteFriendTile({
    super.key,
    required this.friend,
    required this.isInviting,
    this.isPending = false,
    this.isJoined = false,
    this.subtitle,
    required this.onInvite,
    this.onResend,
    this.compact = false,
  });

  final Tomodachi friend;
  final bool isInviting;
  final bool isPending;
  final bool isJoined;
  final String? subtitle;
  final VoidCallback onInvite;
  final VoidCallback? onResend;
  final bool compact;

  String get _subtitle {
    if (subtitle != null) return subtitle!;
    if (isJoined) return 'In party';
    if (isPending) return 'Waiting for response';
    return 'Tap to invite';
  }

  @override
  Widget build(BuildContext context) {
    final canInvite = !isPending && !isJoined && !isInviting;
    final canResend = isPending && !isInviting;
    final verticalPadding = compact ? 4.0 : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        dense: compact,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: verticalPadding,
        ),
        leading: CircleAvatar(
          radius: compact ? 16 : 20,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.25),
          child: Text(
            friend.username.isNotEmpty
                ? friend.username[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 13 : 16,
            ),
          ),
        ),
        title: Text(
          friend.username,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        subtitle: Text(
          _subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: compact ? 11 : 12,
          ),
        ),
        trailing: _buildTrailing(),
        onTap: canInvite
            ? onInvite
            : canResend
                ? onResend
                : null,
      ),
    );
  }

  Widget _buildTrailing() {
    if (isInviting) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (isJoined) {
      return Icon(
        Icons.check_circle_rounded,
        size: compact ? 20 : 24,
        color: Colors.greenAccent.withOpacity(0.95),
      );
    }

    if (isPending) {
      return TextButton(
        onPressed: onResend,
        style: TextButton.styleFrom(
          foregroundColor: Colors.orangeAccent.withOpacity(0.95),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Pending',
          style: TextStyle(fontSize: compact ? 11 : 14),
        ),
      );
    }

    return Icon(
      Icons.send_rounded,
      size: compact ? 18 : 24,
      color: AppTheme.primaryColor.withOpacity(0.9),
    );
  }
}
