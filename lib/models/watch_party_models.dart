import '../services/watch_party_logger.dart';

enum SyncActionType {
  play('PLAY'),
  pause('PAUSE'),
  seek('SEEK'),
  loadVideo('LOAD_VIDEO'),
  syncRequest('SYNC_REQUEST'),
  join('JOIN'),
  leave('LEAVE'),
  leaderChange('LEADER_CHANGE');

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
  final String? leaderId;

  const SyncAction({
    required this.action,
    this.timestamp = 0,
    this.isPlaying = false,
    this.videoUrl,
    this.senderUsername,
    this.leaderId,
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
      leaderId: json['leaderId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.apiValue,
      'timestamp': timestamp,
      'isPlaying': isPlaying,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (senderUsername != null) 'senderUsername': senderUsername,
      if (leaderId != null) 'leaderId': leaderId,
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
  final String leaderId;
  final String? videoUrl;
  final double currentTimeStamp;
  final bool isPlaying;
  final Set<String> members;
  final Set<String> activeMembers;

  const PartyState({
    required this.partyId,
    required this.leaderId,
    this.videoUrl,
    this.currentTimeStamp = 0,
    this.isPlaying = false,
    this.members = const {},
    this.activeMembers = const {},
  });

  factory PartyState.fromJson(Map<String, dynamic> json) {
    return PartyState(
      partyId: json['partyId']?.toString() ?? '',
      leaderId: json['leaderId']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString(),
      currentTimeStamp: SyncAction._parseDouble(json['currentTimeStamp']),
      isPlaying: json['isPlaying'] == true,
      members: _parseStringSet(json['members']),
      activeMembers: _parseStringSet(json['activeMembers']),
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
  final String leaderId;
  final String leaderUsername;

  const WatchPartyInvitePayload({
    required this.partyId,
    required this.inviteToken,
    required this.leaderId,
    required this.leaderUsername,
  });

  factory WatchPartyInvitePayload.fromData(Map<String, dynamic> data) {
    return WatchPartyInvitePayload(
      partyId: data['partyId']?.toString() ?? '',
      inviteToken: data['inviteToken']?.toString() ?? '',
      leaderId: data['leaderId']?.toString() ?? '',
      leaderUsername: data['leaderUsername']?.toString() ?? 'Someone',
    );
  }

  bool get isValid =>
      partyId.isNotEmpty && inviteToken.isNotEmpty && leaderId.isNotEmpty;
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
