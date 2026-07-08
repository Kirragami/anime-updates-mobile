import '../models/watch_party_models.dart';

/// Routes incoming watch-party invites to the app shell for in-app dialog presentation.
class WatchPartyInviteDelivery {
  WatchPartyInviteDelivery._();

  static void Function(WatchPartyInvitePayload payload)? _onInviteReceived;

  static void bind(void Function(WatchPartyInvitePayload payload) onInviteReceived) {
    _onInviteReceived = onInviteReceived;
  }

  static void unbind() {
    _onInviteReceived = null;
  }

  static void deliver(WatchPartyInvitePayload payload) {
    if (!payload.isValid) return;
    _onInviteReceived?.call(payload);
  }
}
