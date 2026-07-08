import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_party_models.dart';
import '../providers/watch_party_provider.dart';
import '../screens/watch_party_lobby_screen.dart';
import 'app_shell_delivery.dart';
import 'auth_service.dart';
import 'watch_party_navigation.dart';

/// Watch-party foreground actions delivered through [AppShellDeliveryCoordinator].
class WatchPartyAppShell {
  WatchPartyAppShell({
    required AppShellDeliveryCoordinator coordinator,
    required WidgetRef Function() ref,
  })  : _coordinator = coordinator,
        _ref = ref;

  static WatchPartyAppShell? _instance;

  static void bind(WatchPartyAppShell shell) {
    _instance = shell;
  }

  static void unbind() {
    _instance = null;
  }

  static void deliverInvite(WatchPartyInvitePayload payload) {
    _instance?.onInviteReceived(payload);
  }

  static void deliverInviteDeclined(WatchPartyDeclinePayload payload) {
    _instance?.onInviteDeclined(payload);
  }

  static void resetSession() {
    _instance?.reset();
  }

  final AppShellDeliveryCoordinator _coordinator;
  final WidgetRef Function() _ref;

  int _lastHandledMemberVideoOpenToken = 0;
  String? _presentingInvitePartyId;

  void onInviteReceived(WatchPartyInvitePayload payload) {
    if (!AuthService.isLoggedIn || !payload.isValid) return;

    _coordinator.enqueue(
      key: 'watch_party_invite:${payload.partyId}',
      action: (context) async {
        if (_presentingInvitePartyId == payload.partyId) {
          return false;
        }

        _presentingInvitePartyId = payload.partyId;
        try {
          await showWatchPartyInviteDialog(context, _ref(), payload);
          return true;
        } finally {
          if (_presentingInvitePartyId == payload.partyId) {
            _presentingInvitePartyId = null;
          }
          _coordinator.scheduleFlush();
        }
      },
    );
  }

  void onInviteDeclined(WatchPartyDeclinePayload payload) {
    if (!AuthService.isLoggedIn || !payload.isValid) return;
    unawaited(_ref().read(watchPartyProvider.notifier).handleInviteDeclined(payload));
  }

  void onPartyStateChanged(
    WatchPartySessionState? previous,
    WatchPartySessionState next,
  ) {
    if (!next.isActive || next.isLeader) {
      resetMemberVideoTracking();
      return;
    }

    final token = next.memberVideoOpenToken;
    if (token <= _lastHandledMemberVideoOpenToken) return;

    final releaseId = next.memberVideoOpenReleaseId;
    if (releaseId == null || releaseId.isEmpty) return;

    _coordinator.enqueue(
      key: 'watch_party_member_video',
      action: (context) => _openMemberVideo(context, releaseId),
    );
  }

  Future<bool> _openMemberVideo(BuildContext context, String releaseId) async {
    final party = _ref().read(watchPartyProvider);
    if (!party.isActive || party.isLeader) {
      return true;
    }

    final token = party.memberVideoOpenToken;
    if (token <= _lastHandledMemberVideoOpenToken) {
      return true;
    }

    final targetReleaseId = party.memberVideoOpenReleaseId ?? releaseId;
    final opened = await WatchPartyNavigation.openMemberVideoFromLeader(
      ref: _ref(),
      context: context,
      releaseId: targetReleaseId,
      appInForeground: true,
    );

    if (opened) {
      _lastHandledMemberVideoOpenToken = token;
    }

    return opened;
  }

  void resetMemberVideoTracking() {
    _lastHandledMemberVideoOpenToken = 0;
    _coordinator.cancel('watch_party_member_video');
  }

  void reset() {
    _presentingInvitePartyId = null;
    resetMemberVideoTracking();
    _coordinator.cancelWhere((key) => key.startsWith('watch_party_'));
  }
}
