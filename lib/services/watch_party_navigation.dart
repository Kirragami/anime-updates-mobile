import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/completed_download.dart';
import '../models/watch_party_models.dart';
import '../providers/download_providers.dart';
import '../providers/watch_party_provider.dart';
import '../app_orientation_system_ui.dart';
import '../screens/video_player_screen.dart';
import 'watch_party_logger.dart';

/// Navigates members to the synced watch-party player when the leader loads a video.
class WatchPartyNavigation {
  WatchPartyNavigation._();

  /// True while a member's party [VideoPlayerScreen] is on the navigation stack.
  static bool _isMemberInPartyPlayer = false;

  static void markMemberInPartyPlayer(bool inPlayer) {
    _isMemberInPartyPlayer = inPlayer;
  }

  /// Clears navigation guards when the member leaves the party entirely.
  static void resetOnPartyLeave() {
    _isMemberInPartyPlayer = false;
  }

  static Future<bool> openMemberVideoFromLeader({
    required WidgetRef ref,
    required BuildContext context,
    required String releaseId,
    required bool appInForeground,
  }) async {
    if (!appInForeground) {
      WatchPartyLogger.warn('auto-open skipped: app not foreground');
      return false;
    }

    final party = ref.read(watchPartyProvider);
    if (!party.isActive || party.isLeader) {
      WatchPartyLogger.warn(
        'auto-open skipped: active=${party.isActive} isLeader=${party.isLeader}',
      );
      return true;
    }

    if (_isMemberInPartyPlayer) {
      WatchPartyLogger.info(
        'auto-open skipped: member already in party player releaseId=$releaseId',
      );
      return true;
    }

    WatchPartyLogger.info('auto-opening member player releaseId=$releaseId');
    return openEpisode(
      ref: ref,
      context: context,
      releaseId: releaseId,
      fromRemoteLoad: true,
    );
  }

  static Future<void> maybeOpenLeaderVideo({
    required WidgetRef ref,
    required BuildContext context,
    required WatchPartySessionState? previous,
    required WatchPartySessionState next,
    required bool appInForeground,
  }) async {
    if (!appInForeground || !next.isActive || next.isLeader) return;

    final releaseId = next.memberVideoOpenReleaseId;
    final tokenChanged =
        releaseId != null &&
        next.memberVideoOpenToken != previous?.memberVideoOpenToken;
    if (tokenChanged) {
      WatchPartyLogger.info(
        'memberVideoOpenToken changed ${previous?.memberVideoOpenToken} -> ${next.memberVideoOpenToken}',
      );
      await openMemberVideoFromLeader(
        ref: ref,
        context: context,
        releaseId: releaseId,
        appInForeground: appInForeground,
      );
      return;
    }

    // Fallback when party state already has a video but no new token was emitted
    // (e.g. member joined while the leader is already watching).
    final videoUrl = next.partyState?.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;
    if (videoUrl == previous?.partyState?.videoUrl) return;

    final videoRef = WatchPartyVideoRef.decode(videoUrl);
    if (videoRef == null) return;

    await openMemberVideoFromLeader(
      ref: ref,
      context: context,
      releaseId: videoRef.releaseId,
      appInForeground: appInForeground,
    );
  }

  /// Returns true when the player screen was opened.
  static Future<bool> openEpisode({
    required WidgetRef ref,
    required BuildContext context,
    required String releaseId,
    required bool fromRemoteLoad,
  }) async {
    final party = ref.read(watchPartyProvider);
    if (party.isActive && party.isLeader && !fromRemoteLoad) {
      ref.read(watchPartyProvider.notifier).notifyLoadVideo(releaseId);
    }

    final filePath =
        await ref.read(completedDownloadsProvider.notifier).getFilePath(releaseId);
    if (!context.mounted) return false;

    if (filePath == null) {
      WatchPartyLogger.warn('episode file missing for releaseId=$releaseId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromRemoteLoad
                ? 'The leader started an episode you have not downloaded'
                : 'Could not find the downloaded file',
          ),
        ),
      );
      return true;
    }

    final downloads = ref.read(completedDownloadsProvider);
    final CompletedDownload? episode = downloads[releaseId];

    final title = episode == null
        ? 'Watch party'
        : '${episode.showName} - Episode ${episode.episode}';

    final activeParty = ref.read(watchPartyProvider);
    if (!context.mounted) return false;

    if (fromRemoteLoad && !activeParty.isLeader) {
      markMemberInPartyPlayer(true);
    }

    final restoreOrientations = AppOrientationSystemUi.orientationsFromContext(context);

    WatchPartyLogger.info(
      'pushing VideoPlayerScreen releaseId=$releaseId watchParty=${activeParty.isActive}',
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          filePath: filePath,
          title: title,
          currentReleaseId: releaseId,
          watchPartyEnabled: activeParty.isActive,
          restoreOrientationsOnExit: restoreOrientations,
        ),
      ),
    );

    if (fromRemoteLoad && !activeParty.isLeader) {
      markMemberInPartyPlayer(false);
    }
    return true;
  }
}
