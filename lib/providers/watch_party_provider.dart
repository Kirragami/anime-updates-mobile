import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_party_models.dart';
import '../services/auth_service.dart';
import '../services/watch_party_logger.dart';
import '../services/watch_party_navigation.dart';
import '../services/watch_party_service.dart';
import '../services/watch_party_socket_service.dart';

class WatchPartySessionState {
  final String? partyId;
  final bool isLeader;
  final PartyState? partyState;
  final bool isConnected;
  final bool isBusy;
  final Set<int> invitingFriendIds;
  final String? invitedFriendName;
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
    this.invitingFriendIds = const {},
    this.invitedFriendName,
    this.errorMessage,
    this.statusMessage,
    this.memberVideoOpenToken = 0,
    this.memberVideoOpenReleaseId,
  });

  bool get isActive => partyId != null && partyId!.isNotEmpty;

  WatchPartySessionState copyWith({
    String? partyId,
    bool? isLeader,
    PartyState? partyState,
    bool? isConnected,
    bool? isBusy,
    Set<int>? invitingFriendIds,
    String? invitedFriendName,
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
      invitingFriendIds: invitingFriendIds ?? this.invitingFriendIds,
      invitedFriendName: invitedFriendName ?? this.invitedFriendName,
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

  WatchPartySocketService get socket => _socket;

  Future<void> inviteFriend({
    required int friendId,
    required String friendUsername,
  }) async {
    if (!AuthService.isLoggedIn) {
      state = state.copyWith(
        errorMessage: 'Please log in to start a watch party',
      );
      return;
    }

    state = state.copyWith(
      invitingFriendIds: {...state.invitingFriendIds, friendId},
      clearError: true,
      clearStatus: true,
    );

    try {
      final invite = await _api.inviteFriend(friendId);
      final userId = AuthService.currentUserId;

      final invitingFriendIds = {...state.invitingFriendIds}..remove(friendId);
      state = state.copyWith(
        partyId: invite.partyId,
        isLeader: true,
        invitedFriendName: friendUsername,
        invitingFriendIds: invitingFriendIds,
        statusMessage: 'Invite sent to $friendUsername',
      );

      await _connectSocket(invite.partyId);
      await refreshState();

      if (userId != null) {
        sendSync(
          SyncAction(
            action: SyncActionType.join,
            leaderId: userId,
          ),
        );
      }
    } catch (e) {
      final invitingFriendIds = {...state.invitingFriendIds}..remove(friendId);
      state = state.copyWith(
        invitingFriendIds: invitingFriendIds,
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

      final userId = AuthService.currentUserId;
      final isLeader = userId == payload.leaderId;

      state = state.copyWith(
        partyId: payload.partyId,
        isLeader: isLeader,
        invitedFriendName: payload.leaderUsername,
        isBusy: false,
        statusMessage: 'Joined ${payload.leaderUsername}\'s watch party',
      );

      await _connectSocket(payload.partyId);
      await refreshState();

      sendSync(
        SyncAction(
          action: SyncActionType.join,
          leaderId: payload.leaderId,
        ),
      );
      sendSync(const SyncAction(action: SyncActionType.syncRequest));
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

  Future<void> refreshState() async {
    final partyId = state.partyId;
    if (partyId == null) return;

    try {
      final partyState = await _api.getPartyState(partyId);
      final userId = AuthService.currentUserId;
      state = state.copyWith(
        partyState: partyState,
        isLeader: userId == partyState.leaderId,
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
        unawaited(refreshState());
      }
    });

    await AuthService.ensureFreshAccessToken();
    final partyState = await _api.getPartyState(partyId);
    final userId = AuthService.currentUserId;
    state = state.copyWith(
      partyState: partyState,
      isLeader: userId == partyState.leaderId,
    );

    if (kDebugMode) {
      print(
        '[WatchParty] connecting socket partyId=$partyId userId=${AuthService.currentUserId}',
      );
    }

    await _socket.connect(partyId);
    state = state.copyWith(isConnected: _socket.isConnected);
  }

  Future<void> _handleIncomingAction(SyncAction action) async {
    switch (action.action) {
      case SyncActionType.join:
      case SyncActionType.leave:
        await refreshState();
        return;
      case SyncActionType.leaderChange:
        final current = state.partyState;
        if (current != null) {
          final updated = PartyState(
            partyId: current.partyId,
            leaderId: action.leaderId ?? current.leaderId,
            videoUrl: current.videoUrl,
            currentTimeStamp: current.currentTimeStamp,
            isPlaying: current.isPlaying,
            members: current.members,
            activeMembers: current.activeMembers,
          );
          final userId = AuthService.currentUserId;
          state = state.copyWith(
            partyState: updated,
            isLeader: userId != null && userId == updated.leaderId,
          );
        }
        await refreshState();
        return;
      case SyncActionType.loadVideo:
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
        updated = PartyState(
          partyId: current.partyId,
          leaderId: action.leaderId ?? current.leaderId,
          videoUrl: action.videoUrl,
          currentTimeStamp: 0,
          isPlaying: false,
          members: current.members,
          activeMembers: current.activeMembers,
        );
        if (kDebugMode) {
          WatchPartyLogger.info(
            'LOAD_VIDEO received videoUrl=${action.videoUrl} isLeader=${state.isLeader}',
          );
        }
        if (!state.isLeader) {
          final releaseId = WatchPartyVideoRef.decode(action.videoUrl)?.releaseId;
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
      case SyncActionType.play:
        updated = PartyState(
          partyId: current.partyId,
          leaderId: current.leaderId,
          videoUrl: current.videoUrl,
          currentTimeStamp: action.timestamp,
          isPlaying: true,
          members: current.members,
          activeMembers: current.activeMembers,
        );
        break;
      case SyncActionType.pause:
        updated = PartyState(
          partyId: current.partyId,
          leaderId: current.leaderId,
          videoUrl: current.videoUrl,
          currentTimeStamp: action.timestamp,
          isPlaying: false,
          members: current.members,
          activeMembers: current.activeMembers,
        );
        break;
      case SyncActionType.seek:
        updated = PartyState(
          partyId: current.partyId,
          leaderId: current.leaderId,
          videoUrl: current.videoUrl,
          currentTimeStamp: action.timestamp,
          isPlaying: action.isPlaying,
          members: current.members,
          activeMembers: current.activeMembers,
        );
        break;
      case SyncActionType.syncRequest:
        updated = PartyState(
          partyId: current.partyId,
          leaderId: action.leaderId ?? current.leaderId,
          videoUrl: action.videoUrl ?? current.videoUrl,
          currentTimeStamp: action.timestamp,
          isPlaying: action.isPlaying,
          members: current.members,
          activeMembers: current.activeMembers,
        );
        if (!state.isLeader) {
          final incomingVideoUrl = action.videoUrl;
          final releaseId =
              WatchPartyVideoRef.decode(incomingVideoUrl)?.releaseId;
          if (releaseId != null && incomingVideoUrl != current.videoUrl) {
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
        partyState: PartyState(
          partyId: current.partyId,
          leaderId: current.leaderId,
          videoUrl: encoded,
          currentTimeStamp: 0,
          isPlaying: false,
          members: current.members,
          activeMembers: current.activeMembers,
        ),
      );
    }

    sendSync(
      SyncAction(
        action: SyncActionType.loadVideo,
        videoUrl: encoded,
        leaderId: AuthService.currentUserId,
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
    final userId = AuthService.currentUserId;
    if (state.isActive && userId != null) {
      sendSync(
        SyncAction(
          action: SyncActionType.leave,
          leaderId: state.partyState?.leaderId,
        ),
      );
    }

    await _actionSub?.cancel();
    await _connectionSub?.cancel();
    await _socket.disconnect();

    WatchPartyNavigation.resetOnPartyLeave();
    state = const WatchPartySessionState();
  }

  @override
  void dispose() {
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
