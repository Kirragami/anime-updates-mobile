import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_party_models.dart';
import '../services/auth_service.dart';
import '../services/watch_party_logger.dart';
import '../services/watch_party_navigation.dart';
import '../services/watch_party_app_shell.dart';
import '../services/watch_party_service.dart';
import '../services/watch_party_socket_service.dart';
import '../services/watch_party_sync_config.dart';

class WatchPartySessionState {
  final String? partyId;
  final bool isLeader;
  final PartyState? partyState;
  final bool isConnected;
  final bool isBusy;
  final Set<String> invitingFriendUsernames;
  final String? errorMessage;
  final String? statusMessage;
  /// Bumps when the leader loads a video so members can auto-open reliably.
  final int memberVideoOpenToken;
  final String? memberVideoOpenReleaseId;

  const WatchPartySessionState({
    this.partyId,
    this.isLeader = false,
    this.partyState,
    this.isConnected = false,
    this.isBusy = false,
    this.invitingFriendUsernames = const {},
    this.errorMessage,
    this.statusMessage,
    this.memberVideoOpenToken = 0,
    this.memberVideoOpenReleaseId,
  });

  bool get isActive => partyId != null && partyId!.isNotEmpty;

  /// Members can rejoin when the leader has started an episode.
  bool get canRejoinLeaderPlayback {
    if (!isActive || isLeader) return false;
    final videoUrl = partyState?.videoUrl;
    return videoUrl != null && videoUrl.isNotEmpty;
  }

  String? get leaderPlaybackReleaseId {
    final videoUrl = partyState?.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return null;
    return WatchPartyVideoRef.decode(videoUrl)?.releaseId;
  }

  WatchPartySessionState copyWith({
    String? partyId,
    bool? isLeader,
    PartyState? partyState,
    bool? isConnected,
    bool? isBusy,
    Set<String>? invitingFriendUsernames,
    String? errorMessage,
    String? statusMessage,
    int? memberVideoOpenToken,
    String? memberVideoOpenReleaseId,
    bool clearMemberVideoOpenReleaseId = false,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return WatchPartySessionState(
      partyId: partyId ?? this.partyId,
      isLeader: isLeader ?? this.isLeader,
      partyState: partyState ?? this.partyState,
      isConnected: isConnected ?? this.isConnected,
      isBusy: isBusy ?? this.isBusy,
      invitingFriendUsernames: invitingFriendUsernames ?? this.invitingFriendUsernames,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      memberVideoOpenToken: memberVideoOpenToken ?? this.memberVideoOpenToken,
      memberVideoOpenReleaseId: clearMemberVideoOpenReleaseId
          ? null
          : (memberVideoOpenReleaseId ?? this.memberVideoOpenReleaseId),
    );
  }
}

class WatchPartyNotifier extends StateNotifier<WatchPartySessionState> {
  WatchPartyNotifier() : super(const WatchPartySessionState());

  final WatchPartyService _api = WatchPartyService();
  final WatchPartySocketService _socket = WatchPartySocketService();

  StreamSubscription<SyncAction>? _actionSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _reconnectTimer;
  Timer? _keepaliveTimer;

  static const _reconnectDelay = Duration(seconds: 3);

  WatchPartySocketService get socket => _socket;

  Future<void> inviteFriend({
    required String friendUsername,
  }) async {
    if (!AuthService.isLoggedIn) {
      state = state.copyWith(
        errorMessage: 'Please log in to start a watch party',
      );
      return;
    }

    state = state.copyWith(
      invitingFriendUsernames: {...state.invitingFriendUsernames, friendUsername},
      clearError: true,
      clearStatus: true,
    );

    try {
      final invite = await _api.inviteFriend(friendUsername);
      final isContinuingParty =
          state.isActive && state.isLeader && state.partyId == invite.partyId;

      final invitingFriendUsernames = {...state.invitingFriendUsernames}
        ..remove(friendUsername);
      final currentPartyState = state.partyState;
      final optimisticPartyState = currentPartyState?.copyWith(
        pendingInviteUsernames: {
          ...currentPartyState.pendingInviteUsernames,
          friendUsername,
        },
      );

      state = state.copyWith(
        partyId: invite.partyId,
        isLeader: true,
        partyState: optimisticPartyState ?? currentPartyState,
        invitingFriendUsernames: invitingFriendUsernames,
        statusMessage: 'Invite sent to $friendUsername',
      );

      if (isContinuingParty) {
        await refreshState();
      } else {
        await _connectSocket(invite.partyId);
        await refreshState();
      }
    } catch (e) {
      final invitingFriendUsernames = {...state.invitingFriendUsernames}
        ..remove(friendUsername);
      state = state.copyWith(
        invitingFriendUsernames: invitingFriendUsernames,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> acceptInvite(WatchPartyInvitePayload payload) async {
    if (!payload.isValid) {
      state = state.copyWith(errorMessage: 'Invalid watch party invite');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true, clearStatus: true);

    try {
      await _api.acceptInvite(
        partyId: payload.partyId,
        token: payload.inviteToken,
      );

      final username = AuthService.currentUsername;
      final isLeader = username == payload.leaderUsername;

      state = state.copyWith(
        partyId: payload.partyId,
        isLeader: isLeader,
        isBusy: false,
        statusMessage: 'Joined ${payload.leaderUsername}\'s watch party',
      );

      await _connectSocket(payload.partyId);
      await refreshState();
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> declineInvite(WatchPartyInvitePayload payload) async {
    if (!payload.isValid) return;

    try {
      await _api.declineInvite(
        partyId: payload.partyId,
        token: payload.inviteToken,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[WatchParty] decline failed: $e');
      }
    }
  }

  Future<void> handleInviteDeclined(WatchPartyDeclinePayload payload) async {
    if (!payload.isValid) return;
    if (!state.isActive || state.partyId != payload.partyId || !state.isLeader) {
      return;
    }

    final currentPartyState = state.partyState;
    final updatedPartyState = currentPartyState?.copyWith(
      pendingInviteUsernames: currentPartyState.pendingInviteUsernames
          .where((name) => name != payload.declinedUsername)
          .toSet(),
    );

    state = state.copyWith(
      partyState: updatedPartyState ?? currentPartyState,
      statusMessage: '${payload.declinedUsername} declined the invite',
    );

    await refreshState();
  }

  Future<void> refreshState() async {
    final partyId = state.partyId;
    if (partyId == null) return;

    try {
      final partyState = await _api.getPartyState(partyId);
      final username = AuthService.currentUsername;
      state = state.copyWith(
        partyState: partyState,
        isLeader: username == partyState.leaderUsername,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _connectSocket(String partyId) async {
    await _actionSub?.cancel();
    await _connectionSub?.cancel();

    _actionSub = _socket.actions.listen((action) {
      unawaited(_handleIncomingAction(action));
    });
    _connectionSub = _socket.connectionChanges.listen((connected) {
      state = state.copyWith(isConnected: connected);
      if (connected && state.partyId != null) {
        _announcePresence();
        _startKeepalive();
        unawaited(refreshState());
      } else if (!connected && state.partyId != null) {
        _stopKeepalive();
        unawaited(_scheduleReconnect());
      }
    });

    await AuthService.ensureFreshAccessToken();
    final partyState = await _api.getPartyState(partyId);
    final username = AuthService.currentUsername;
    state = state.copyWith(
      partyState: partyState,
      isLeader: username == partyState.leaderUsername,
    );

    if (kDebugMode) {
      print(
        '[WatchParty] connecting socket partyId=$partyId username=${AuthService.currentUsername}',
      );
    }

    await _socket.connect(partyId);
    state = state.copyWith(isConnected: _socket.isConnected);
  }

  Future<void> _handleIncomingAction(SyncAction action) async {
    switch (action.action) {
      case SyncActionType.join:
      case SyncActionType.leave:
        _applyMembershipBroadcast(action);
        return;
      case SyncActionType.presence:
        _applyPresenceUpdate(action);
        return;
      case SyncActionType.heartbeat:
        return;
      case SyncActionType.leaderChange:
        final current = state.partyState;
        if (current != null) {
          final updated = current.copyWith(
            leaderUsername: action.leaderUsername ?? current.leaderUsername,
          );
          final username = AuthService.currentUsername;
          state = state.copyWith(
            partyState: updated,
            isLeader: username != null && username == updated.leaderUsername,
          );
        }
        await refreshState();
        if (!state.isConnected && state.isActive) {
          unawaited(_scheduleReconnect());
        }
        return;
      case SyncActionType.loadVideo:
      case SyncActionType.stopVideo:
      case SyncActionType.play:
      case SyncActionType.pause:
      case SyncActionType.seek:
      case SyncActionType.syncRequest:
        break;
    }

    var current = state.partyState;
    if (current == null) {
      await refreshState();
      current = state.partyState;
      if (current == null) return;
    }

    PartyState updated = current;
    switch (action.action) {
      case SyncActionType.loadVideo:
        updated = current.copyWith(
          leaderUsername: action.leaderUsername ?? current.leaderUsername,
          videoUrl: action.videoUrl,
          currentTimeStamp: 0,
          isPlaying: false,
        );
        if (kDebugMode) {
          WatchPartyLogger.info(
            'LOAD_VIDEO received videoUrl=${action.videoUrl} isLeader=${state.isLeader}',
          );
        }
        if (!state.isLeader) {
          final releaseId = WatchPartyVideoRef.decode(action.videoUrl)?.releaseId;
          if (WatchPartyNavigation.isMemberInPartyPlayer) {
            state = state.copyWith(partyState: updated);
            WatchPartyAppShell.acknowledgePendingMemberVideoOpen();
            return;
          }
          WatchPartyLogger.info(
            'member auto-open signal releaseId=$releaseId token=${state.memberVideoOpenToken + 1}',
          );
          state = state.copyWith(
            partyState: updated,
            memberVideoOpenReleaseId: releaseId,
            memberVideoOpenToken: state.memberVideoOpenToken + 1,
          );
          return;
        }
        break;
      case SyncActionType.stopVideo:
        updated = current.copyWith(
          clearVideoUrl: true,
          currentTimeStamp: 0,
          isPlaying: false,
        );
        if (!state.isLeader) {
          state = state.copyWith(
            partyState: updated,
            statusMessage: 'Leader stopped watching',
            clearMemberVideoOpenReleaseId: true,
          );
          WatchPartyAppShell.acknowledgePendingMemberVideoOpen();
          return;
        }
        break;
      case SyncActionType.play:
        updated = current.copyWith(
          currentTimeStamp: action.timestamp,
          isPlaying: true,
        );
        break;
      case SyncActionType.pause:
        updated = current.copyWith(
          currentTimeStamp: action.timestamp,
          isPlaying: false,
        );
        break;
      case SyncActionType.seek:
        updated = current.copyWith(
          currentTimeStamp: action.timestamp,
          isPlaying: action.isPlaying,
        );
        break;
      case SyncActionType.syncRequest:
        updated = current.copyWith(
          leaderUsername: action.leaderUsername ?? current.leaderUsername,
          videoUrl: action.videoUrl ?? current.videoUrl,
          currentTimeStamp: action.timestamp,
          isPlaying: action.isPlaying,
        );
        if (!state.isLeader) {
          final incomingVideoUrl = action.videoUrl;
          final releaseId =
              WatchPartyVideoRef.decode(incomingVideoUrl)?.releaseId;
          if (releaseId != null && incomingVideoUrl != current.videoUrl) {
            if (WatchPartyNavigation.isMemberInPartyPlayer) {
              state = state.copyWith(partyState: updated);
              WatchPartyAppShell.acknowledgePendingMemberVideoOpen();
              return;
            }
            WatchPartyLogger.info(
              'SYNC_REQUEST video open releaseId=$releaseId videoUrl=$incomingVideoUrl',
            );
            state = state.copyWith(
              partyState: updated,
              memberVideoOpenReleaseId: releaseId,
              memberVideoOpenToken: state.memberVideoOpenToken + 1,
            );
            return;
          }
        }
        break;
      case SyncActionType.join:
      case SyncActionType.leave:
      case SyncActionType.leaderChange:
      case SyncActionType.presence:
      case SyncActionType.heartbeat:
        return;
    }

    state = state.copyWith(partyState: updated);
  }

  void sendSync(SyncAction action) {
    final sent = _socket.sendSync(action);
    if (!sent) {
      WatchPartyLogger.warn(
        'failed to send ${action.action.apiValue}: connected=${_socket.isConnected}',
      );
    }
  }

  void notifyLoadVideo(String releaseId) {
    if (!state.isLeader) {
      WatchPartyLogger.warn('notifyLoadVideo ignored: not leader');
      return;
    }

    final encoded = WatchPartyVideoRef(releaseId).encode();
    WatchPartyLogger.info('notifyLoadVideo releaseId=$releaseId encoded=$encoded');

    final current = state.partyState;
    if (current != null) {
      state = state.copyWith(
        partyState: current.copyWith(
          videoUrl: encoded,
          currentTimeStamp: 0,
          isPlaying: false,
        ),
      );
    }

    sendSync(
      SyncAction(
        action: SyncActionType.loadVideo,
        videoUrl: encoded,
        leaderUsername: AuthService.currentUsername,
      ),
    );
  }

  void notifyStopVideo() {
    if (!state.isLeader) {
      WatchPartyLogger.warn('notifyStopVideo ignored: not leader');
      return;
    }

    final currentVideoUrl = state.partyState?.videoUrl;
    if (currentVideoUrl == null || currentVideoUrl.isEmpty) {
      WatchPartyLogger.info('notifyStopVideo skipped: no active video');
      return;
    }

    WatchPartyLogger.info('notifyStopVideo clearing videoUrl=$currentVideoUrl');

    final current = state.partyState;
    if (current != null) {
      state = state.copyWith(
        partyState: current.copyWith(
          clearVideoUrl: true,
          currentTimeStamp: 0,
          isPlaying: false,
        ),
      );
    }

    sendSync(
      SyncAction(
        action: SyncActionType.stopVideo,
        leaderUsername: AuthService.currentUsername,
      ),
    );
  }

  void notifyPlay(double timestampSeconds) {
    if (!state.isLeader) return;
    sendSync(
      SyncAction(
        action: SyncActionType.play,
        timestamp: timestampSeconds,
        isPlaying: true,
      ),
    );
  }

  void notifyPause(double timestampSeconds) {
    if (!state.isLeader) return;
    sendSync(
      SyncAction(
        action: SyncActionType.pause,
        timestamp: timestampSeconds,
        isPlaying: false,
      ),
    );
  }

  void notifySeek(double timestampSeconds, {required bool isPlaying}) {
    if (!state.isLeader) return;
    sendSync(
      SyncAction(
        action: SyncActionType.seek,
        timestamp: timestampSeconds,
        isPlaying: isPlaying,
      ),
    );
  }

  Future<void> leaveParty() async {
    _cancelReconnect();
    _stopKeepalive();
    final username = AuthService.currentUsername;
    if (state.isActive && username != null) {
      sendSync(
        SyncAction(
          action: SyncActionType.leave,
          leaderUsername: state.partyState?.leaderUsername,
        ),
      );
    }

    await _actionSub?.cancel();
    await _connectionSub?.cancel();
    await _socket.disconnect();

    WatchPartyNavigation.resetOnPartyLeave();
    WatchPartyAppShell.resetSession();
    state = const WatchPartySessionState();
  }

  void _applyPresenceUpdate(SyncAction action) {
    final current = state.partyState;
    if (current == null || action.activeMembers == null) {
      unawaited(refreshState());
      return;
    }

    state = state.copyWith(
      partyState: current.copyWith(activeMembers: action.activeMembers!),
    );
  }

  void _applyMembershipBroadcast(SyncAction action) {
    final current = state.partyState;
    if (current == null || action.members == null) {
      unawaited(refreshState());
      return;
    }

    final updatedMembers = action.members!;
    final updatedActiveMembers = action.activeMembers != null
        ? action.activeMembers!
        : _activeMembersForRemainingMembers(
            current.activeMembers,
            updatedMembers,
          );
    final updatedPartyState = current.copyWith(
      members: updatedMembers,
      activeMembers: updatedActiveMembers,
      pendingInviteUsernames: _pendingInvitesExcludingMembers(
        current.pendingInviteUsernames,
        updatedMembers,
      ),
    );

    final senderName = action.senderUsername;
    String? statusMessage;
    if (senderName != null && senderName.isNotEmpty) {
      statusMessage = action.action == SyncActionType.join
          ? '$senderName joined the party'
          : '$senderName left the party';
    }

    state = state.copyWith(
      partyState: updatedPartyState,
      statusMessage: statusMessage,
    );
  }

  Set<String> _pendingInvitesExcludingMembers(
    Set<String> pendingInviteUsernames,
    Set<String> joinedMemberUsernames,
  ) {
    return pendingInviteUsernames
        .where((username) => !joinedMemberUsernames.contains(username))
        .toSet();
  }

  Set<String> _activeMembersForRemainingMembers(
    Set<String> activeMembers,
    Set<String> joinedMemberUsernames,
  ) {
    return activeMembers
        .where((username) => joinedMemberUsernames.contains(username))
        .toSet();
  }

  void _sendKeepalive() {
    if (!state.isActive || !_socket.isConnected) return;
    sendSync(const SyncAction(action: SyncActionType.heartbeat));
  }

  void _startKeepalive() {
    _stopKeepalive();
    _sendKeepalive();
    _keepaliveTimer = Timer.periodic(
      WatchPartySyncConfig.keepaliveInterval,
      (_) => _sendKeepalive(),
    );
  }

  void _stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  void _announcePresence() {
    final leaderUsername =
        state.partyState?.leaderUsername ?? AuthService.currentUsername;
    sendSync(
      SyncAction(
        action: SyncActionType.join,
        leaderUsername: leaderUsername,
      ),
    );
    if (!state.isLeader) {
      sendSync(const SyncAction(action: SyncActionType.syncRequest));
    }
  }

  Future<void> _scheduleReconnect() async {
    if (!state.isActive || _reconnectTimer != null) return;

    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectTimer = null;
      final partyId = state.partyId;
      if (partyId == null) return;

      try {
        await _socket.connect(partyId);
        state = state.copyWith(isConnected: _socket.isConnected);
      } catch (e) {
        WatchPartyLogger.warn('watch party reconnect failed: $e');
        if (state.isActive) {
          unawaited(_scheduleReconnect());
        }
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void clearStatusMessage() {
    if (state.statusMessage == null) return;
    state = state.copyWith(clearStatus: true);
  }

  @override
  void dispose() {
    _cancelReconnect();
    _stopKeepalive();
    _actionSub?.cancel();
    _connectionSub?.cancel();
    _socket.dispose();
    super.dispose();
  }
}

final watchPartyProvider =
    StateNotifierProvider<WatchPartyNotifier, WatchPartySessionState>((ref) {
  final notifier = WatchPartyNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final watchPartySocketProvider = Provider<WatchPartySocketService>((ref) {
  return ref.watch(watchPartyProvider.notifier).socket;
});

final watchPartyActiveProvider = Provider<bool>((ref) {
  return ref.watch(watchPartyProvider).isActive;
});

/// True while [WatchPartyLobbyScreen] is the active route (hides floating panel).
final watchPartyLobbyVisibleProvider = StateProvider<bool>((ref) => false);

/// True while [VideoPlayerScreen] is the active route (hides floating panel).
final watchPartyVideoPlayerVisibleProvider = StateProvider<bool>((ref) => false);

final watchPartyRouteObserver = RouteObserver<ModalRoute<void>>();

bool watchPartyPanelHiddenForCurrentRoute(WidgetRef ref) {
  return ref.read(watchPartyLobbyVisibleProvider) ||
      ref.read(watchPartyVideoPlayerVisibleProvider);
}
