/// Watch party sync tuning.
///
/// [keepaliveInterval] stays below common proxy idle limits (e.g. Cloudflare ~100s).
class WatchPartySyncConfig {
  WatchPartySyncConfig._();

  /// WebSocket keepalive traffic interval for all party members.
  static const keepaliveInterval = Duration(seconds: 30);

  /// How often members request a playback check while in the party player.
  static const playbackSyncInterval = Duration(seconds: 30);

  /// Ignore position drift below this during periodic sync checks.
  static const periodicDriftThresholdMs = 2500;

  /// Apply leader seeks immediately when drift exceeds this (scrub, play, pause).
  static const eventDriftThresholdMs = 750;
}
