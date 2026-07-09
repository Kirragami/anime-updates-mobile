import '../services/watch_party_logger.dart';

enum SyncActionType {
  play('PLAY'),
  pause('PAUSE'),
  seek('SEEK'),
  loadVideo('LOAD_VIDEO'),
  stopVideo('STOP_VIDEO'),
  syncRequest('SYNC_REQUEST'),
  join('JOIN'),
  leave('LEAVE'),
  leaderChange('LEADER_CHANGE'),
  presence('PRESENCE'),
  heartbeat('HEARTBEAT');

  const SyncActionType(this.apiValue);
  final String apiValue;

  static SyncActionType? fromApi(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in SyncActionType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

class SyncAction {
  final SyncActionType action;
  final double timestamp;
  final bool isPlaying;
  final String? videoUrl;
  final String? senderUsername;
  final String? leaderUsername;
  final Set<String>? activeMembers;
  final Set<String>? members;

  const SyncAction({
    required this.action,
    this.timestamp = 0,
    this.isPlaying = false,
    this.videoUrl,
    this.senderUsername,
    this.leaderUsername,
    this.activeMembers,
    this.members,
  });

  factory SyncAction.fromJson(Map<String, dynamic> json) {
    final actionType = SyncActionType.fromApi(json['action']?.toString());
    if (actionType == null) {
      WatchPartyLogger.warn('unknown action field: ${json['action']} raw=$json');
    }
    return SyncAction(
      action: actionType ?? SyncActionType.syncRequest,
      timestamp: _parseDouble(json['timestamp']),
      isPlaying: json['isPlaying'] == true,
      videoUrl: json['videoUrl']?.toString(),
      senderUsername: json['senderUsername']?.toString(),
      leaderUsername: json['leaderUsername']?.toString(),
      activeMembers: json.containsKey('activeMembers')
          ? PartyState._parseStringSet(json['activeMembers'])
          : null,
      members: json.containsKey('members')
          ? PartyState._parseStringSet(json['members'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.apiValue,
      'timestamp': timestamp,
      'isPlaying': isPlaying,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (senderUsername != null) 'senderUsername': senderUsername,
      if (leaderUsername != null) 'leaderUsername': leaderUsername,
      if (activeMembers != null) 'activeMembers': activeMembers!.toList(),
      if (members != null) 'members': members!.toList(),
    };
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PartyInviteResult {
  final String partyId;
  final String inviteToken;

  const PartyInviteResult({
    required this.partyId,
    required this.inviteToken,
  });

  factory PartyInviteResult.fromJson(Map<String, dynamic> json) {
    return PartyInviteResult(
      partyId: json['partyId']?.toString() ?? '',
      inviteToken: json['inviteToken']?.toString() ?? '',
    );
  }
}

class PartyState {
  final String partyId;
  final String leaderUsername;
  final String? videoUrl;
  final double currentTimeStamp;
  final bool isPlaying;
  final Set<String> members;
  final Set<String> activeMembers;
  final Set<String> pendingInviteUsernames;

  const PartyState({
    required this.partyId,
    required this.leaderUsername,
    this.videoUrl,
    this.currentTimeStamp = 0,
    this.isPlaying = false,
    this.members = const {},
    this.activeMembers = const {},
    this.pendingInviteUsernames = const {},
  });

  factory PartyState.fromJson(Map<String, dynamic> json) {
    return PartyState(
      partyId: json['partyId']?.toString() ?? '',
      leaderUsername: json['leaderUsername']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString(),
      currentTimeStamp: SyncAction._parseDouble(json['currentTimeStamp']),
      isPlaying: json['isPlaying'] == true,
      members: _parseStringSet(json['members']),
      activeMembers: _parseStringSet(json['activeMembers']),
      pendingInviteUsernames: _parseStringSet(json['pendingInviteUsernames']),
    );
  }

  PartyState copyWith({
    String? partyId,
    String? leaderUsername,
    String? videoUrl,
    bool clearVideoUrl = false,
    double? currentTimeStamp,
    bool? isPlaying,
    Set<String>? members,
    Set<String>? activeMembers,
    Set<String>? pendingInviteUsernames,
  }) {
    return PartyState(
      partyId: partyId ?? this.partyId,
      leaderUsername: leaderUsername ?? this.leaderUsername,
      videoUrl: clearVideoUrl ? null : (videoUrl ?? this.videoUrl),
      currentTimeStamp: currentTimeStamp ?? this.currentTimeStamp,
      isPlaying: isPlaying ?? this.isPlaying,
      members: members ?? this.members,
      activeMembers: activeMembers ?? this.activeMembers,
      pendingInviteUsernames:
          pendingInviteUsernames ?? this.pendingInviteUsernames,
    );
  }

  static Set<String> _parseStringSet(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    if (value is Set) {
      return value.map((e) => e.toString()).toSet();
    }
    return {};
  }
}

class WatchPartyInvitePayload {
  final String partyId;
  final String inviteToken;
  final String leaderUsername;

  const WatchPartyInvitePayload({
    required this.partyId,
    required this.inviteToken,
    required this.leaderUsername,
  });

  factory WatchPartyInvitePayload.fromData(Map<String, dynamic> data) {
    return WatchPartyInvitePayload(
      partyId: data['partyId']?.toString() ?? '',
      inviteToken: data['inviteToken']?.toString() ?? '',
      leaderUsername: data['leaderUsername']?.toString() ?? 'Someone',
    );
  }

  bool get isValid =>
      partyId.isNotEmpty &&
      inviteToken.isNotEmpty &&
      leaderUsername.isNotEmpty;
}

class WatchPartyDeclinePayload {
  final String partyId;
  final String declinedUsername;

  const WatchPartyDeclinePayload({
    required this.partyId,
    required this.declinedUsername,
  });

  factory WatchPartyDeclinePayload.fromData(Map<String, dynamic> data) {
    return WatchPartyDeclinePayload(
      partyId: data['partyId']?.toString() ?? '',
      declinedUsername: data['declinedUsername']?.toString() ?? 'Someone',
    );
  }

  bool get isValid => partyId.isNotEmpty && declinedUsername.isNotEmpty;
}

/// Identifies a locally downloaded episode across party members.
class WatchPartyVideoRef {
  static const prefix = 'release:';

  final String releaseId;

  const WatchPartyVideoRef(this.releaseId);

  String encode() => '$prefix$releaseId';

  static WatchPartyVideoRef? decode(String? value) {
    if (value == null || !value.startsWith(prefix)) return null;
    final releaseId = value.substring(prefix.length);
    if (releaseId.isEmpty) return null;
    return WatchPartyVideoRef(releaseId);
  }
}
