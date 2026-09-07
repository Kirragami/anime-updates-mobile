import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:async';
import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme/app_theme.dart';
import '../models/completed_download.dart';
import '../models/watch_party_models.dart';
import '../providers/watch_party_provider.dart';
import '../services/auth_service.dart';
import '../services/completed_downloads_manager.dart';
import '../services/playback_progress_manager.dart';
import '../services/watch_party_logger.dart';
import '../services/watch_party_navigation.dart';
import '../services/watch_party_app_shell.dart';
import '../services/watch_party_sync_config.dart';
import '../services/usb_stream_server.dart';
import '../widgets/watch_party_invite_friends_sheet.dart';
import '../app_orientation_system_ui.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String? title;

  final String? currentReleaseId;
  final bool watchPartyEnabled;
  final List<DeviceOrientation> restoreOrientationsOnExit;

  const VideoPlayerScreen({
    super.key,
    required this.filePath,
    required this.restoreOrientationsOnExit,
    this.title,
    this.currentReleaseId,
    this.watchPartyEnabled = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with RouteAware {
  ModalRoute<void>? _route;

  VlcPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isControlsVisible = true;
  bool _isFullscreen = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _controlsTimer;
  Timer? _positionTimer;
  Timer? _scrubSeekTimer;
  double _volume = 100.0;
  double _brightness = 1.0;

  /// Live scrubbing: UI follows the thumb immediately; native seeks are throttled.
  bool _isScrubbing = false;
  Duration? _pendingScrubSeek;
  int _seekGeneration = 0;
  DateTime? _lastNativeSeekAt;
  DateTime? _ignorePollPositionUntil;
  DateTime? _ignorePollPlayingUntil;
  DateTime? _lastProgressSaveAt;
  Duration? _queuedSeekWhileRecovering;

  static const Duration _nativeSeekMinInterval = Duration(milliseconds: 100);
  static const Duration _progressSaveInterval = Duration(seconds: 10);

  bool _isVolumeControlVisible = false;
  bool _isBrightnessControlVisible = false;
  bool _isGestureActive = false;
  double _gestureStartY = 0.0;
  double _initialVolume = 100.0;
  double _initialBrightness = 1.0;
  double? _doubleTapX;

  bool _isSeekIndicatorVisible = false;
  String _seekIndicatorText = '';
  DateTime? _lastSeekTime;
  int _consecutiveSeekCount = 0;
  Timer? _seekIndicatorTimer;

  late String _activeFilePath;
  late String? _activeTitle;
  late String? _activeReleaseId;

  final FocusNode _focusNode = FocusNode();

  CompletedDownload? _prevEpisode;
  CompletedDownload? _nextEpisode;
  bool _autoAdvancedCalled = false;
  bool _isRecoveringFromEnd = false;

  StreamSubscription<SyncAction>? _partyActionSub;
  bool _applyingRemoteSync = false;
  bool _partyInitialized = false;
  String? _loadedPartyVideoUrl;
  bool _watchPartyExitHandled = false;
  bool _periodicSyncPending = false;
  Timer? _partySeekDebounce;
  Timer? _partyPlaybackSyncTimer;
  SyncAction? _pendingRemoteSync;

  final UsbStreamServer _usbStream = UsbStreamServer();
  bool _usbStreaming = false;

  /// Bumped on every media load so in-flight init/seek callbacks cannot
  /// touch a newer episode (or a player that USB streaming already released).
  int _mediaLoadGeneration = 0;

  /// True while swapping or creating media. Blocks ended auto-advance and
  /// remote watch-party control until the new file is actually ready.
  bool _isLoadingMedia = false;

  /// libVLC can keep `isEnded` true until the replacement media opens.
  /// Ignore that stale flag so we don't skip through the new episode.
  bool _ignoreEndedUntilReady = false;

  bool get _watchPartyActive =>
      widget.watchPartyEnabled && ref.read(watchPartyProvider).isActive;

  bool get _isPartyLeader =>
      _watchPartyActive && ref.read(watchPartyProvider).isLeader;

  bool get _playerReadyForControl =>
      _videoPlayerController != null && _isInitialized && !_isLoadingMedia;

  static int? _extractEpisodeNumber(String episode) {
    final cleaned = episode
        .toLowerCase()
        .replaceAll('episode', '')
        .replaceAll('ep', '')
        .trim();
    final match = RegExp(r'\d+').firstMatch(cleaned);
    if (match != null) return int.tryParse(match.group(0)!);
    return null;
  }

  String? _getAnimeShowId() {
    final currentId = _activeReleaseId;
    if (currentId == null) return null;
    final manager = CompletedDownloadsManager();
    final all = manager.completedDownloads.values.toList();
    try {
      final current = all.firstWhere((e) => e.releaseId == currentId);
      return current.animeShowId ?? current.showName;
    } catch (_) {
      return null;
    }
  }

  List<CompletedDownload> _episodesInCurrentShow() {
    final currentId = _activeReleaseId;
    if (currentId == null) return const [];

    final manager = CompletedDownloadsManager();
    final all = manager.completedDownloads.values.toList();
    CompletedDownload? current;
    try {
      current = all.firstWhere((e) => e.releaseId == currentId);
    } catch (_) {
      return const [];
    }

    final showKey = current.animeShowId ?? current.showName;
    final numbered = all
        .where((e) => (e.animeShowId ?? e.showName) == showKey)
        .map((e) => MapEntry(_extractEpisodeNumber(e.episode), e))
        .where((e) => e.key != null)
        .toList()
      ..sort((a, b) => a.key!.compareTo(b.key!));

    final episodes = numbered.map((e) => e.value).toList();
    if (episodes.every((e) => e.releaseId != currentId)) {
      episodes.add(current);
    }
    return episodes;
  }

  void _resolveAdjacentEpisodes() {
    final currentId = _activeReleaseId;
    final episodes = _episodesInCurrentShow();
    if (currentId == null || episodes.isEmpty) {
      _setAdjacentEpisodes();
      return;
    }

    final index = episodes.indexWhere((e) => e.releaseId == currentId);
    if (index < 0) {
      _setAdjacentEpisodes();
      return;
    }

    _setAdjacentEpisodes(
      previous: index > 0 ? episodes[index - 1] : null,
      next: index < episodes.length - 1 ? episodes[index + 1] : null,
    );
  }

  void _setAdjacentEpisodes({
    CompletedDownload? previous,
    CompletedDownload? next,
  }) {
    if (!mounted) return;
    setState(() {
      _prevEpisode = previous;
      _nextEpisode = next;
    });
  }

  Future<void> _switchToEpisode(CompletedDownload episode) async {
    final manager = CompletedDownloadsManager();
    final filePath = await manager.getFilePath(episode.releaseId);
    if (filePath == null || !mounted) return;

    if (_isPartyLeader) {
      ref.read(watchPartyProvider.notifier).notifyLoadVideo(episode.releaseId);
      _loadedPartyVideoUrl = WatchPartyVideoRef(episode.releaseId).encode();
    }

    if (_usbStreaming) {
      setState(() {
        _activeFilePath = filePath;
        _activeTitle = '${episode.showName} - Episode ${episode.episode}';
        _activeReleaseId = episode.releaseId;
        _autoAdvancedCalled = false;
      });
      await _usbStream.playRelease(episode.releaseId);
      _resolveAdjacentEpisodes();
      return;
    }

    _persistProgress(force: true);

    setState(() {
      _activeFilePath = filePath;
      _activeTitle = '${episode.showName} - Episode ${episode.episode}';
      _activeReleaseId = episode.releaseId;
    });

    _resolveAdjacentEpisodes();
    await _loadMedia();
  }
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    _activeFilePath = widget.filePath;
    _activeTitle = widget.title;
    _activeReleaseId = widget.currentReleaseId;

    _resolveAdjacentEpisodes();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setSystemUIChangeCallback(
        (bool isSystemOverlaysVisible) async {
      if (isSystemOverlaysVisible && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      }
    });

    _getInitialBrightness();
    _initializePlayer();
    _setupWatchPartySync();
  }

  void _setupWatchPartySync() {
    if (!widget.watchPartyEnabled) return;

    _partyActionSub = ref
        .read(watchPartySocketProvider)
        .actions
        .listen(_handlePartySyncAction);

    ref.listen<WatchPartySessionState>(watchPartyProvider, (previous, next) {
      if (!widget.watchPartyEnabled || !next.isActive) return;
      final videoUrl = next.partyState?.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) return;
      if (_isPartyLeader) return;
      if (videoUrl == _loadedPartyVideoUrl) return;

      final videoRef = WatchPartyVideoRef.decode(videoUrl);
      if (videoRef == null) return;
      if (videoRef.releaseId == _activeReleaseId) {
        _loadedPartyVideoUrl = videoUrl;
        return;
      }

      _loadPartyEpisode(videoRef.releaseId, videoUrl);
    });
  }

  Future<void> _loadPartyEpisode(String releaseId, String videoUrl) async {
    final manager = CompletedDownloadsManager();
    final filePath = await manager.getFilePath(releaseId);
    if (filePath == null || !mounted) {
      return;
    }

    _loadedPartyVideoUrl = videoUrl;
    WatchPartyNavigation.markMemberInPartyPlayer(true);

    _stopPartyPlaybackSync();
    _partyInitialized = false;

    final download = manager.completedDownloads[releaseId];
    setState(() {
      _activeFilePath = filePath;
      _activeTitle = download == null
          ? 'Watch party'
          : '${download.showName} - Episode ${download.episode}';
      _activeReleaseId = releaseId;
    });

    if (_usbStreaming) {
      await _usbStream.playRelease(releaseId);
      _resolveAdjacentEpisodes();
      return;
    }

    _resolveAdjacentEpisodes();
    await _loadMedia(initialSeekSeconds: 0, autoPlay: false);
  }

  void _handlePartySyncAction(SyncAction action) {
    if (!_watchPartyActive || _applyingRemoteSync) return;

    final myUsername = AuthService.currentUsername;
    if (myUsername != null &&
        action.senderUsername == myUsername &&
        action.action != SyncActionType.syncRequest) {
      return;
    }

    WatchPartyLogger.info(
      'player received ${action.action.apiValue} ts=${action.timestamp} '
      'playing=${action.isPlaying} leader=$_isPartyLeader',
    );

    switch (action.action) {
      case SyncActionType.play:
      case SyncActionType.pause:
      case SyncActionType.seek:
        _queueOrApplyRemoteSync(action);
        return;
      case SyncActionType.loadVideo:
        if (_isPartyLeader) return;
        final loadRef = WatchPartyVideoRef.decode(action.videoUrl);
        if (loadRef != null) {
          _loadPartyEpisode(loadRef.releaseId, action.videoUrl ?? '');
        }
        return;
      case SyncActionType.stopVideo:
        if (_isPartyLeader) return;
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      case SyncActionType.syncRequest:
        if (_isPartyLeader) {
          _respondToSyncRequest();
          return;
        }
        final videoRef = WatchPartyVideoRef.decode(action.videoUrl);
        if (videoRef != null && videoRef.releaseId != _activeReleaseId) {
          _loadPartyEpisode(videoRef.releaseId, action.videoUrl ?? '');
        }
        return;
      case SyncActionType.leaderChange:
        ref.read(watchPartyProvider.notifier).refreshState();
        return;
      case SyncActionType.join:
      case SyncActionType.leave:
        ref.read(watchPartyProvider.notifier).refreshState();
        return;
      case SyncActionType.presence:
      case SyncActionType.heartbeat:
        return;
    }
  }

  void _queueOrApplyRemoteSync(SyncAction action) {
    if (!_playerReadyForControl) {
      _pendingRemoteSync = action;
      return;
    }

    switch (action.action) {
      case SyncActionType.play:
        _applyRemotePlayback(
          timestampSeconds: action.timestamp,
          shouldPlay: true,
        );
        break;
      case SyncActionType.pause:
        _applyRemotePlayback(
          timestampSeconds: action.timestamp,
          shouldPlay: false,
        );
        break;
      case SyncActionType.seek:
        final threshold = _periodicSyncPending
            ? WatchPartySyncConfig.periodicDriftThresholdMs
            : WatchPartySyncConfig.eventDriftThresholdMs;
        _periodicSyncPending = false;
        _applyRemotePlayback(
          timestampSeconds: action.timestamp,
          shouldPlay: action.isPlaying,
          seekThresholdMs: threshold,
        );
        break;
      default:
        break;
    }
  }

  void _flushPendingRemoteSync() {
    final pending = _pendingRemoteSync;
    if (pending == null) return;
    _pendingRemoteSync = null;
    _queueOrApplyRemoteSync(pending);
  }

  void _respondToSyncRequest() {
    if (!_isPartyLeader || !_playerReadyForControl) {
      return;
    }

    final seconds = _position.inMilliseconds / 1000.0;
    ref.read(watchPartyProvider.notifier).sendSync(
          SyncAction(
            action: SyncActionType.seek,
            timestamp: seconds,
            isPlaying: _isPlaying,
          ),
        );
  }

  Future<void> _applyRemotePlayback({
    required double timestampSeconds,
    required bool shouldPlay,
    int seekThresholdMs = WatchPartySyncConfig.eventDriftThresholdMs,
  }) async {
    if (!_playerReadyForControl) return;

    _applyingRemoteSync = true;
    try {
      final target = Duration(milliseconds: (timestampSeconds * 1000).round());
      final drift = (_position - target).inMilliseconds.abs();
      if (drift > seekThresholdMs) {
        _ignorePollPositionUntil =
            DateTime.now().add(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() => _position = target);
        }
        await _videoPlayerController!.seekTo(target);
      }

      if (shouldPlay && !_isPlaying) {
        _ignorePollPlayingUntil =
            DateTime.now().add(const Duration(milliseconds: 500));
        if (mounted) setState(() => _isPlaying = true);
        await _videoPlayerController!.play();
      } else if (!shouldPlay && _isPlaying) {
        _ignorePollPlayingUntil =
            DateTime.now().add(const Duration(milliseconds: 500));
        if (mounted) setState(() => _isPlaying = false);
        await _videoPlayerController!.pause();
      }
    } finally {
      _applyingRemoteSync = false;
    }
  }

  void _emitPartyPlayState({required bool playing}) {
    if (!_watchPartyActive || _applyingRemoteSync) return;

    _videoPlayerController?.getPosition().then((pos) {
      if (!mounted || !_watchPartyActive || _applyingRemoteSync) return;
      final seconds = pos.inMilliseconds / 1000.0;
      WatchPartyLogger.info(
        'party emit ${playing ? 'PLAY' : 'PAUSE'} ts=$seconds leader=$_isPartyLeader',
      );
      if (playing) {
        ref.read(watchPartyProvider.notifier).notifyPlay(seconds);
      } else {
        ref.read(watchPartyProvider.notifier).notifyPause(seconds);
      }
    });
  }

  void _emitPartySeek({Duration? at}) {
    if (!_isPartyLeader || _applyingRemoteSync) return;
    _partySeekDebounce?.cancel();
    _partySeekDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_isPartyLeader || _applyingRemoteSync) return;
      final seconds = (at ?? _position).inMilliseconds / 1000.0;
      WatchPartyLogger.info('leader emit SEEK ts=$seconds playing=$_isPlaying');
      ref.read(watchPartyProvider.notifier).notifySeek(
            seconds,
            isPlaying: _isPlaying,
          );
    });
  }

  void _requestPeriodicPlaybackSync() {
    if (!_watchPartyActive || _isPartyLeader || !_playerReadyForControl) {
      return;
    }
    _periodicSyncPending = true;
    ref.read(watchPartyProvider.notifier).sendSync(
          const SyncAction(action: SyncActionType.syncRequest),
        );
  }

  void _startPartyPlaybackSync() {
    _partyPlaybackSyncTimer?.cancel();
    if (!_watchPartyActive || _isPartyLeader) return;

    _partyPlaybackSyncTimer = Timer.periodic(
      WatchPartySyncConfig.playbackSyncInterval,
      (_) => _requestPeriodicPlaybackSync(),
    );
  }

  void _stopPartyPlaybackSync() {
    _partyPlaybackSyncTimer?.cancel();
    _partyPlaybackSyncTimer = null;
    _periodicSyncPending = false;
  }

  Future<void> _getInitialBrightness() async {
    try {
      final screenBrightness = ScreenBrightness();
      _brightness = await screenBrightness.current ?? 1.0;
    } catch (e) {
      _brightness = 1.0;
    }
  }

  VlcPlayerOptions _vlcPlayerOptions() {
    return VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        // Local files: shorter file cache keeps seeks/resumes snappy.
        VlcAdvancedOptions.fileCaching(300),
      ]),
      subtitle: VlcSubtitleOptions([
        VlcSubtitleOptions.boldStyle(true),
        VlcSubtitleOptions.fontSize(20),
        VlcSubtitleOptions.color(VlcSubtitleColor.white),
      ]),
    );
  }

  bool _isControllerInitialized(VlcPlayerController controller) {
    try {
      return controller.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  void _resetPlaybackUiForNewMedia() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _scrubSeekTimer?.cancel();
    _scrubSeekTimer = null;
    _pendingScrubSeek = null;
    _isScrubbing = false;
    _isRecoveringFromEnd = false;
    _queuedSeekWhileRecovering = null;
    _ignoreEndedUntilReady = true;
    _autoAdvancedCalled = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
  }

  void _initializePlayer({
    double? initialSeekSeconds,
    bool? autoPlay,
  }) {
    unawaited(_loadMedia(
      initialSeekSeconds: initialSeekSeconds,
      autoPlay: autoPlay,
    ));
  }

  Future<void> _loadMedia({
    double? initialSeekSeconds,
    bool? autoPlay,
  }) async {
    final generation = ++_mediaLoadGeneration;
    _isLoadingMedia = true;
    _resetPlaybackUiForNewMedia();
    // Reuse path is never entered from initState, so this setState is safe.
    if (_videoPlayerController != null && mounted) {
      setState(() {});
    }

    final file = File(_activeFilePath);
    print('[VideoPlayerScreen] Using file URI: ${file.uri}');

    try {
      final existing = _videoPlayerController;
      if (existing != null) {
        var ready = _isControllerInitialized(existing);
        if (!ready) {
          ready = await _waitUntilControllerInitialized(existing, generation);
        }
        if (!mounted || generation != _mediaLoadGeneration) return;
        if (ready) {
          await _swapMediaOnController(
            existing,
            file,
            generation: generation,
            initialSeekSeconds: initialSeekSeconds,
            autoPlay: autoPlay,
          );
          return;
        }

        try {
          await existing.stop();
        } catch (_) {}
        try {
          await existing.dispose();
        } catch (_) {}
        _videoPlayerController = null;
      }

      if (!mounted || generation != _mediaLoadGeneration) return;
      _createPlayerController(
        file,
        generation: generation,
        initialSeekSeconds: initialSeekSeconds,
        autoPlay: autoPlay,
      );
    } catch (e, stackTrace) {
      print('[VideoPlayerScreen] Error initializing video player: $e');
      print('[VideoPlayerScreen] Stack trace: $stackTrace');
      if (mounted && generation == _mediaLoadGeneration) {
        _isLoadingMedia = false;
      }
    }
  }

  void _createPlayerController(
    File file, {
    required int generation,
    double? initialSeekSeconds,
    bool? autoPlay,
  }) {
    final controller = VlcPlayerController.file(
      file,
      hwAcc: HwAcc.full,
      autoPlay: false,
      options: _vlcPlayerOptions(),
    );
    _videoPlayerController = controller;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _mediaLoadGeneration) {
          setState(() {});
        }
      });
    }

    controller.addOnInitListener(() {
      if (!mounted || generation != _mediaLoadGeneration) return;
      setState(() => _isInitialized = true);
      unawaited(_preparePlaybackAfterMediaChange(
        controller,
        generation: generation,
        initialSeekSeconds: initialSeekSeconds,
        autoPlay: autoPlay,
      ));
    });
  }

  Future<void> _swapMediaOnController(
    VlcPlayerController controller,
    File file, {
    required int generation,
    double? initialSeekSeconds,
    bool? autoPlay,
  }) async {
    try {
      await controller.setMediaFromFile(
        file,
        autoPlay: false,
        hwAcc: HwAcc.full,
      );
    } catch (e) {
      print('[VideoPlayerScreen] setMediaFromFile failed, recreating: $e');
      if (!mounted || generation != _mediaLoadGeneration) return;
      await _recreatePlayerController(
        file,
        generation: generation,
        initialSeekSeconds: initialSeekSeconds,
        autoPlay: autoPlay,
      );
      return;
    }

    if (!mounted || generation != _mediaLoadGeneration) return;
    await _preparePlaybackAfterMediaChange(
      controller,
      generation: generation,
      initialSeekSeconds: initialSeekSeconds,
      autoPlay: autoPlay,
    );
  }

  Future<void> _recreatePlayerController(
    File file, {
    required int generation,
    double? initialSeekSeconds,
    bool? autoPlay,
  }) async {
    final old = _videoPlayerController;
    _videoPlayerController = null;
    if (mounted) {
      setState(() => _isInitialized = false);
    }
    try {
      await old?.stop();
    } catch (_) {}
    try {
      await old?.dispose();
    } catch (_) {}
    await Future<void>.delayed(Duration.zero);
    if (!mounted || generation != _mediaLoadGeneration) return;
    _createPlayerController(
      file,
      generation: generation,
      initialSeekSeconds: initialSeekSeconds,
      autoPlay: autoPlay,
    );
  }

  Future<bool> _waitUntilControllerInitialized(
    VlcPlayerController controller,
    int generation,
  ) async {
    if (_isControllerInitialized(controller)) return true;

    final completer = Completer<bool>();
    late final VoidCallback listener;
    listener = () {
      if (generation != _mediaLoadGeneration) {
        controller.removeListener(listener);
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      if (_isControllerInitialized(controller) && !completer.isCompleted) {
        controller.removeListener(listener);
        completer.complete(true);
      }
    };
    controller.addListener(listener);
    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          controller.removeListener(listener);
          return _isControllerInitialized(controller);
        },
      );
    } catch (_) {
      controller.removeListener(listener);
      return false;
    }
  }

  Duration? _resolveStartPosition(double? initialSeekSeconds) {
    if (initialSeekSeconds != null) {
      final target = Duration(
        milliseconds: (initialSeekSeconds * 1000).round(),
      );
      return target > Duration.zero ? target : null;
    }
    if (_watchPartyActive) return null;

    final showId = _getAnimeShowId();
    if (showId == null || _activeReleaseId == null) return null;
    final lastPos =
        PlaybackProgressManager().getPosition(showId, _activeReleaseId!);
    if (lastPos <= 0) return null;
    return Duration(seconds: lastPos);
  }

  /// Completes only on a *new* Playing event after [play] is issued.
  /// Stale duration/isPlaying from the previous file is ignored.
  Future<bool> _playAndWaitUntilPlaying(
    VlcPlayerController controller,
    int generation,
  ) async {
    final completer = Completer<bool>();
    late final VoidCallback listener;
    listener = () {
      if (generation != _mediaLoadGeneration) {
        controller.removeListener(listener);
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      try {
        final value = controller.value;
        if (value.isPlaying && !value.isEnded && !completer.isCompleted) {
          controller.removeListener(listener);
          completer.complete(true);
        }
      } catch (_) {
        controller.removeListener(listener);
        if (!completer.isCompleted) completer.complete(false);
      }
    };

    controller.addListener(listener);
    try {
      // Force a Playing transition. After setMediaFromFile the Dart
      // controller can still report the previous file as playing/ended.
      try {
        final value = controller.value;
        if (value.isPlaying || value.isEnded) {
          await controller.stop();
        }
      } catch (_) {}
      await controller.play();
    } catch (_) {}

    try {
      return await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          controller.removeListener(listener);
          return false;
        },
      );
    } catch (_) {
      controller.removeListener(listener);
      return false;
    }
  }

  Future<void> _seekAfterPlaying(
    VlcPlayerController controller,
    Duration position,
  ) async {
    try {
      if (controller.value.isEnded) {
        await _resumeFromEndedAt(controller, position);
        return;
      }
      await controller.seekTo(position);
    } catch (_) {
      try {
        await controller.play();
        await _waitForPlayableState(controller);
        await controller.seekTo(position);
      } catch (_) {}
    }
  }

  Future<void> _preparePlaybackAfterMediaChange(
    VlcPlayerController controller, {
    required int generation,
    double? initialSeekSeconds,
    bool? autoPlay,
  }) async {
    final shouldAutoPlay =
        autoPlay ?? (!_watchPartyActive || _isPartyLeader);
    final startPosition = _resolveStartPosition(initialSeekSeconds);

    try {
      // Watch-party members must open the file without leaking audio before
      // the leader's pending sync lands.
      if (!shouldAutoPlay) {
        try {
          await controller.setVolume(0);
        } catch (_) {}
      }

      await _playAndWaitUntilPlaying(controller, generation);
      if (!mounted || generation != _mediaLoadGeneration) return;

      if (startPosition != null) {
        _ignorePollPositionUntil =
            DateTime.now().add(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() => _position = startPosition);
        }
        await _seekAfterPlaying(controller, startPosition);
      }

      if (!mounted || generation != _mediaLoadGeneration) return;

      if (shouldAutoPlay) {
        try {
          if (!controller.value.isPlaying) {
            await controller.play();
          }
        } catch (_) {}
        if (mounted && generation == _mediaLoadGeneration) {
          setState(() => _isPlaying = true);
          _startControlsTimer();
        }
      } else {
        try {
          await controller.pause();
        } catch (_) {}
        if (mounted && generation == _mediaLoadGeneration) {
          setState(() => _isPlaying = false);
        }
      }

      try {
        await controller.setVolume(_volume.toInt());
      } catch (_) {}
    } catch (e) {
      print('[VideoPlayerScreen] Error preparing playback: $e');
    }

    if (!mounted || generation != _mediaLoadGeneration) return;

    _ignoreEndedUntilReady = false;
    _isLoadingMedia = false;
    if (mounted) setState(() {});

    if (_watchPartyActive && !_partyInitialized) {
      _partyInitialized = true;
      if (_isPartyLeader) {
        _loadedPartyVideoUrl =
            WatchPartyVideoRef(_activeReleaseId ?? '').encode();
      } else {
        WatchPartyNavigation.markMemberInPartyPlayer(true);
        ref.read(watchPartyProvider.notifier).sendSync(
            const SyncAction(action: SyncActionType.syncRequest));
        _startPartyPlaybackSync();
      }
    }

    _flushPendingRemoteSync();
    _startPositionUpdates();
  }

  void _startPositionUpdates() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _videoPlayerController == null) {
        timer.cancel();
        _positionTimer = null;
        return;
      }
      if (_isRecoveringFromEnd) return;

      final controller = _videoPlayerController!;
      final now = DateTime.now();
      final ignorePosition = _isScrubbing ||
          (_ignorePollPositionUntil != null &&
              now.isBefore(_ignorePollPositionUntil!));
      final ignorePlaying = _ignorePollPlayingUntil != null &&
          now.isBefore(_ignorePollPlayingUntil!);

      Future.wait([
        ignorePosition
            ? Future<Duration?>.value(null)
            : controller.getPosition(),
        _duration > Duration.zero
            ? Future<Duration?>.value(null)
            : controller.getDuration(),
        ignorePlaying
            ? Future<bool?>.value(null)
            : controller.isPlaying(),
      ]).then((results) {
        if (!mounted || _isRecoveringFromEnd) return;

        final position = results[0] as Duration?;
        final duration = results[1] as Duration?;
        final playing = results[2] as bool?;

        Duration? displayedPosition;
        if (position != null && !_isScrubbing) {
          displayedPosition = controller.value.isEnded &&
                  position == Duration.zero &&
                  _duration > Duration.zero
              ? _duration
              : position;
        }

        final bool? nextPlaying =
            playing == null ? null : playing == true;
        final bool playingChanged =
            nextPlaying != null && nextPlaying != _isPlaying;

        if (displayedPosition != null ||
            (duration != null && duration > Duration.zero) ||
            playingChanged) {
          setState(() {
            if (displayedPosition != null) {
              _position = displayedPosition;
            }
            if (duration != null && duration > Duration.zero) {
              _duration = duration;
            }
            if (nextPlaying != null) {
              _isPlaying = nextPlaying;
            }
          });
        }

        if (playingChanged && nextPlaying == true && _isControlsVisible) {
          _startControlsTimer();
        }

        if (displayedPosition != null &&
            _isPlaying &&
            displayedPosition.inSeconds > 0) {
          _persistProgress(force: false);
        }

        if (!_isScrubbing &&
            !_isLoadingMedia &&
            !_ignoreEndedUntilReady &&
            controller.value.isEnded &&
            !_isRecoveringFromEnd &&
            !_autoAdvancedCalled &&
            _nextEpisode != null &&
            _duration.inSeconds > 0) {
          _autoAdvancedCalled = true;
          timer.cancel();
          _positionTimer = null;
          _switchToEpisode(_nextEpisode!);
        }
      });
    });
  }

  void _persistProgress({bool force = true}) {
    if (!_isInitialized) return;
    final showId = _getAnimeShowId();
    if (showId == null || _activeReleaseId == null) return;
    if (_position.inSeconds <= 0) return;

    final now = DateTime.now();
    if (!force &&
        _lastProgressSaveAt != null &&
        now.difference(_lastProgressSaveAt!) < _progressSaveInterval) {
      return;
    }
    _lastProgressSaveAt = now;

    String? episode;
    try {
      final manager = CompletedDownloadsManager();
      final download = manager.completedDownloads[_activeReleaseId!];
      episode = download?.episode;
    } catch (_) {}

    PlaybackProgressManager().saveProgress(
      showId,
      _activeReleaseId!,
      _position.inSeconds,
      episode: episode,
    );
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoPlayerController;
    if (controller == null || _isLoadingMedia) return;

    if (_isPlaying) {
      setState(() => _isPlaying = false);
      _ignorePollPlayingUntil =
          DateTime.now().add(const Duration(milliseconds: 500));
      _startControlsTimer();
      try {
        await controller.pause();
      } catch (_) {}
      // Party emit stays after native pause so timestamp matches paused media.
      _emitPartyPlayState(playing: false);
      _persistProgress(force: true);
    } else {
      setState(() => _isPlaying = true);
      _ignorePollPlayingUntil =
          DateTime.now().add(const Duration(milliseconds: 500));
      _startControlsTimer();
      try {
        if (controller.value.isEnded) {
          await _resumeFromEndedAt(controller, Duration.zero);
        } else {
          await controller.play();
        }
      } catch (_) {
        if (mounted) setState(() => _isPlaying = false);
      }
      _emitPartyPlayState(playing: true);
    }
  }

  Duration _clampSeekPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && position > _duration) return _duration;
    return position;
  }

  /// [fromScrub] keeps live seeking while dragging, but throttles native seeks.
  Future<void> _seekTo(Duration position, {bool fromScrub = false}) async {
    final controller = _videoPlayerController;
    if (controller == null || _isLoadingMedia) return;

    final target = _clampSeekPosition(position);

    // Optimistic thumb/time — never wait on native for UI.
    _ignorePollPositionUntil =
        DateTime.now().add(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _position = target);
    }

    // Preserve existing party debounce behavior (250ms collapse of seek spam).
    _emitPartySeek(at: target);

    if (fromScrub) {
      _pendingScrubSeek = target;
      final last = _lastNativeSeekAt;
      final now = DateTime.now();
      if (last != null && now.difference(last) < _nativeSeekMinInterval) {
        final wait = _nativeSeekMinInterval - now.difference(last);
        _scrubSeekTimer?.cancel();
        _scrubSeekTimer = Timer(wait, () {
          _scrubSeekTimer = null;
          final pending = _pendingScrubSeek;
          if (pending != null && mounted) {
            _performNativeSeek(pending);
          }
        });
        return;
      }
    } else {
      _scrubSeekTimer?.cancel();
      _scrubSeekTimer = null;
      _pendingScrubSeek = null;
    }

    await _performNativeSeek(target);
  }

  Future<void> _performNativeSeek(Duration position) async {
    final controller = _videoPlayerController;
    if (controller == null || _isLoadingMedia) return;

    final generation = ++_seekGeneration;
    _lastNativeSeekAt = DateTime.now();
    _pendingScrubSeek = null;

    if (_isRecoveringFromEnd) {
      _queuedSeekWhileRecovering = position;
      return;
    }

    try {
      if (controller.value.isEnded) {
        await _resumeFromEndedAt(controller, position);
      } else {
        await controller.seekTo(position);
      }
    } catch (_) {
      // Ignore stale native errors; newer seeks supersede.
    }

    if (generation != _seekGeneration) return;
  }

  Future<void> _resumeFromEndedAt(
    VlcPlayerController controller,
    Duration position,
  ) async {
    if (_isRecoveringFromEnd) {
      _queuedSeekWhileRecovering = position;
      return;
    }

    setState(() => _isRecoveringFromEnd = true);
    try {
      // libVLC does not reliably seek while its media is in the ended state.
      // Restart the existing controller first, then seek once it is playable.
      await controller.stop();
      await controller.play();
      await _waitForPlayableState(controller);
      final latest = _queuedSeekWhileRecovering ?? position;
      _queuedSeekWhileRecovering = null;
      await controller.seekTo(latest);
      if (mounted) {
        setState(() => _position = latest);
      }
    } finally {
      if (mounted) {
        setState(() => _isRecoveringFromEnd = false);
      }
      final queued = _queuedSeekWhileRecovering;
      _queuedSeekWhileRecovering = null;
      if (queued != null && mounted) {
        await _performNativeSeek(queued);
      }
    }
  }

  Future<void> _waitForPlayableState(VlcPlayerController controller) async {
    if (!controller.value.isEnded && controller.value.isPlaying) return;

    final completer = Completer<void>();
    late final VoidCallback listener;
    listener = () {
      final value = controller.value;
      if (!value.isEnded && value.isPlaying && !completer.isCompleted) {
        controller.removeListener(listener);
        completer.complete();
      }
    };

    controller.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      controller.removeListener(listener);
      // Give the native player a brief opportunity to process play before
      // attempting the seek, even if it did not emit the expected event.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _startControlsTimer() {
    if (_usbStreaming) {
      _controlsTimer?.cancel();
      return;
    }
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AppOrientationSystemUi.sync());
  }

  void _onVerticalDragStart(DragStartDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;

    if (x < screenWidth * 0.3) {
      setState(() {
        _isBrightnessControlVisible = true;
        _isControlsVisible = false;
        _isGestureActive = true;
        _gestureStartY = details.globalPosition.dy;
        _initialBrightness = _brightness;
      });
    } else if (x > screenWidth * 0.7) {
      setState(() {
        _isVolumeControlVisible = true;
        _isControlsVisible = false;
        _isGestureActive = true;
        _gestureStartY = details.globalPosition.dy;
        _initialVolume = _volume;
      });
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;
    final deltaPercent = (deltaY / screenHeight) * 100;

    if (_isBrightnessControlVisible) {
      double newBrightness = _initialBrightness + (deltaPercent / 100);
      newBrightness = newBrightness.clamp(0.0, 1.0);
      setState(() {
        _brightness = newBrightness;
      });
      _setBrightness(newBrightness);
    } else if (_isVolumeControlVisible) {
      double newVolume = _initialVolume + deltaPercent;
      newVolume = newVolume.clamp(0.0, 100.0);
      setState(() {
        _volume = newVolume;
      });
      _setVolume(newVolume);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isGestureActive = false;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isGestureActive) {
        setState(() {
          _isBrightnessControlVisible = false;
          _isVolumeControlVisible = false;
        });
      }
    });
  }

  void _setVolume(double volume) {
    _videoPlayerController?.setVolume(volume.toInt());
  }

  Future<void> _setBrightness(double brightness) async {
    try {
      final screenBrightness = ScreenBrightness();
      await screenBrightness.setScreenBrightness(brightness);
    } catch (e) {
      print('[VideoPlayerScreen] Error setting brightness: $e');
    }
  }

  void _handleDoubleTapCenter() {
    _togglePlayPause();
  }

  void _handleDoubleTapLeft() {
    _rewind();
  }

  void _handleDoubleTapRight() {
    _forward();
  }

  void _rewind() {
    _updateSeekAmount();
    final newPosition = _position - Duration(seconds: _getCurrentSeekAmount());
    _seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _showSeekIndicator('-${_getCurrentSeekAmount()}s');
  }

  void _forward() {
    _updateSeekAmount();
    final newPosition = _position + Duration(seconds: _getCurrentSeekAmount());
    if (newPosition <= _duration) {
      _seekTo(newPosition);
    } else {
      _seekTo(_duration);
    }
    _showSeekIndicator('+${_getCurrentSeekAmount()}s');
  }

  void _updateSeekAmount() {
    final now = DateTime.now();
    if (_lastSeekTime != null &&
        now.difference(_lastSeekTime!).inMilliseconds < 1000) {
      _consecutiveSeekCount++;
    } else {
      _consecutiveSeekCount = 1;
    }
    _lastSeekTime = now;
  }

  int _getCurrentSeekAmount() {
    int amount = 10 + (_consecutiveSeekCount - 1) * 5;
    return amount < 10 ? 10 : (amount > 30 ? 30 : amount);
  }

  void _showSeekIndicator(String text) {
    setState(() {
      _isSeekIndicatorVisible = true;
      _seekIndicatorText = text;
    });

    _seekIndicatorTimer?.cancel();

    _seekIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isSeekIndicatorVisible = false;
        });
      }
    });
  }

  void _adjustVolume(bool increase) {
    double newVolume = _volume;
    if (increase) {
      newVolume = (_volume + 5).clamp(0.0, 100.0);
    } else {
      newVolume = (_volume - 5).clamp(0.0, 100.0);
    }

    setState(() {
      _volume = newVolume;
      _isVolumeControlVisible = true;
      _isControlsVisible = false;
    });

    _setVolume(_volume);

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isVolumeControlVisible = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _resetBrightness() {
    ScreenBrightness().resetScreenBrightness().catchError((Object e) {
      print('[VideoPlayerScreen] Error resetting brightness: $e');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      _route = route;
      watchPartyRouteObserver.subscribe(this, route);
      if (route.isCurrent) {
        ref.read(watchPartyVideoPlayerVisibleProvider.notifier).state = true;
      }
    }
  }

  @override
  void didPush() {
    ref.read(watchPartyVideoPlayerVisibleProvider.notifier).state = true;
  }

  @override
  void didPopNext() {
    ref.read(watchPartyVideoPlayerVisibleProvider.notifier).state = true;
  }

  @override
  void didPop() {
    ref.read(watchPartyVideoPlayerVisibleProvider.notifier).state = false;
    _handleWatchPartyPlayerExit();
  }

  @override
  void dispose() {
    watchPartyRouteObserver.unsubscribe(this);
    SystemChrome.setSystemUIChangeCallback(null);
    SystemChrome.setPreferredOrientations(widget.restoreOrientationsOnExit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppOrientationSystemUi.sync();
    });

    WakelockPlus.disable();

    _persistProgress(force: true);
    _partyActionSub?.cancel();
    _partySeekDebounce?.cancel();
    _stopPartyPlaybackSync();
    _controlsTimer?.cancel();
    _positionTimer?.cancel();
    _scrubSeekTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _mediaLoadGeneration++;
    _isLoadingMedia = false;
    final controller = _videoPlayerController;
    _videoPlayerController = null;
    if (controller != null) {
      unawaited(() async {
        try {
          await controller.stop();
        } catch (_) {}
        try {
          await controller.dispose();
        } catch (_) {}
      }());
    }
    _focusNode.dispose();
    _resetBrightness();
    _usbStream.playingReleaseId.removeListener(_onUsbPlayingReleaseChanged);
    unawaited(_usbStream.stop());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Theme(
        data: Theme.of(context).copyWith(
          // Set focus and highlight colors to transparent to hide Flutter's focus indicators
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is KeyDownEvent) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.space:
                  _togglePlayPause();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowLeft:
                  _rewind();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowRight:
                  _forward();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  _adjustVolume(true);
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowDown:
                  _adjustVolume(false);
                  return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
              _doubleTapX = details.globalPosition.dx;
            },
            onDoubleTap: () {
              if (_doubleTapX == null) return;
              final screenWidth = MediaQuery.of(context).size.width;
              if (_doubleTapX! < screenWidth * 0.4) {
                _handleDoubleTapLeft();
              } else if (_doubleTapX! > screenWidth * 0.6) {
                _handleDoubleTapRight();
              } else {
                _handleDoubleTapCenter();
              }
            },
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: _usbStreaming
                      ? _buildUsbStreamIdleScreen()
                      : _videoPlayerController != null
                          ? VlcPlayer(
                              key: ObjectKey(_videoPlayerController),
                              controller: _videoPlayerController!,
                              aspectRatio: 16 / 9,
                              placeholder: Container(
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                ),
                if (_isLoadingMedia && !_usbStreaming)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isBrightnessControlVisible)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: _buildBrightnessControl(),
                  ),
                if (_isVolumeControlVisible)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: _buildVolumeControl(),
                  ),
                if (_isSeekIndicatorVisible)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _seekIndicatorText.startsWith('-')
                                ? Icons.replay
                                : Icons.forward,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _seekIndicatorText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                IgnorePointer(
                  ignoring: !_isControlsVisible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isControlsVisible ? 1.0 : 0.0,
                    child: Listener(
                      onPointerDown: (_) {
                        if (_isControlsVisible) _startControlsTimer();
                      },
                      child: _buildControlsOverlay(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  void _showInviteFriendsPopup() {
    showWatchPartyInviteFriendsSheet(context);
  }

  void _handleWatchPartyPlayerExit() {
    if (_watchPartyExitHandled) return;
    _watchPartyExitHandled = true;

    final party = ref.read(watchPartyProvider);
    if (!party.isActive) return;

    if (party.isLeader) {
      final videoUrl = party.partyState?.videoUrl;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        ref.read(watchPartyProvider.notifier).notifyStopVideo();
      }
      return;
    }

    if (widget.watchPartyEnabled) {
      WatchPartyNavigation.markMemberInPartyPlayer(false);
      WatchPartyAppShell.cancelPendingMemberVideoOpen();
    }
  }

  void _exitPlayer() {
    _handleWatchPartyPlayerExit();
    Navigator.of(context).pop();
  }

  Future<void> _releaseLocalPlayer() async {
    _persistProgress(force: true);
    _positionTimer?.cancel();
    _positionTimer = null;
    _scrubSeekTimer?.cancel();
    _scrubSeekTimer = null;
    _pendingScrubSeek = null;
    _isScrubbing = false;
    _mediaLoadGeneration++;
    _isLoadingMedia = false;
    _ignoreEndedUntilReady = false;

    final old = _videoPlayerController;
    if (old == null) return;

    setState(() {
      _videoPlayerController = null;
      _isInitialized = false;
      _isPlaying = false;
    });

    try {
      await old.stop();
    } catch (_) {}
    try {
      await old.dispose();
    } catch (_) {}
  }

  Future<void> _onUsbStreamButtonTap() async {
    if (_usbStreaming) {
      await _stopUsbStream();
      return;
    }

    try {
      final items = await _usbPlaylistItems();
      if (items.isEmpty) {
        throw StateError('No downloaded episodes to stream');
      }
      await _usbStream.start(
        items: items,
        currentReleaseId: _activeReleaseId ?? items.first.releaseId,
      );
      _usbStream.playingReleaseId.addListener(_onUsbPlayingReleaseChanged);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start USB stream: $e')),
      );
      return;
    }
    if (!mounted) return;
    await _releaseLocalPlayer();
    if (!mounted) return;
    setState(() {
      _usbStreaming = true;
      _isControlsVisible = true;
    });
    _startControlsTimer();
  }

  Future<List<UsbStreamItem>> _usbPlaylistItems() async {
    final manager = CompletedDownloadsManager();
    final items = <UsbStreamItem>[];
    for (final episode in _episodesInCurrentShow()) {
      final path = await manager.getFilePath(episode.releaseId);
      if (path == null) continue;
      items.add(
        UsbStreamItem(
          releaseId: episode.releaseId,
          filePath: path,
          title: '${episode.showName} - Episode ${episode.episode}',
        ),
      );
    }
    return items;
  }

  void _onUsbPlayingReleaseChanged() {
    if (!_usbStreaming || !mounted) return;
    final releaseId = _usbStream.playingReleaseId.value;
    if (releaseId == null || releaseId == _activeReleaseId) return;

    final download =
        CompletedDownloadsManager().completedDownloads[releaseId];
    final itemPath = _usbStream.filePathFor(releaseId);
    setState(() {
      _activeReleaseId = releaseId;
      if (itemPath != null) {
        _activeFilePath = itemPath;
      }
      _activeTitle = download == null
          ? _activeTitle
          : '${download.showName} - Episode ${download.episode}';
    });
    _resolveAdjacentEpisodes();
  }

  Future<void> _stopUsbStream() async {
    _usbStream.playingReleaseId.removeListener(_onUsbPlayingReleaseChanged);
    await _usbStream.stop();
    if (!mounted) return;
    setState(() => _usbStreaming = false);
    _initializePlayer();
  }

  Widget _buildUsbStreamIdleScreen() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: _usbStream.clientCount,
          builder: (context, count, _) {
            final connected = count > 0;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.usb_rounded,
                      size: 22,
                      color: Colors.white.withOpacity(connected ? 0.55 : 0.28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      connected
                          ? 'Connected'
                          : 'Waiting for connection',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (_activeTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _activeTitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.32),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Connect from your PC',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _usbGuideStep('1', 'Enable USB debugging on this phone'),
                    _usbGuideStep('2', 'Connect the USB cable'),
                    _usbGuideStep(
                      '3',
                      'On the PC, confirm adb sees the phone:  adb devices',
                    ),
                    _usbGuideStep('4', 'Run this command:'),
                    const SizedBox(height: 8),
                    const SelectableText(
                      UsbStreamServer.pcCommand,
                      style: TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _usbGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              color: Colors.white.withOpacity(0.28),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitPlayer,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (_activeTitle != null)
            Expanded(
              child: Text(
                _activeTitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_watchPartyActive)
            GestureDetector(
              onTap: _isPartyLeader ? _showInviteFriendsPopup : null,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPartyLeader
                          ? Icons.person_add_alt_1_rounded
                          : Icons.sync_rounded,
                      size: 14,
                      color: AppTheme.primaryColor.withOpacity(0.95),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPartyLeader ? 'Leader' : 'Synced',
                      style: TextStyle(
                        color: AppTheme.primaryColor.withOpacity(0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _onUsbStreamButtonTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.usb_rounded,
                color: _usbStreaming
                    ? Colors.white.withOpacity(0.95)
                    : Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_usbStreaming) {
      return _buildUsbStreamBottomControls();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: AppTheme.primaryColor,
                    overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? _position.inMilliseconds
                            .clamp(0, _duration.inMilliseconds)
                            .toDouble()
                        : 0.0,
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 100.0,
                    onChangeStart: (_) {
                      setState(() => _isScrubbing = true);
                    },
                    onChanged: (value) {
                      _seekTo(
                        Duration(milliseconds: value.toInt()),
                        fromScrub: true,
                      );
                    },
                    onChangeEnd: (value) {
                      _isScrubbing = false;
                      _seekTo(
                        Duration(milliseconds: value.toInt()),
                        fromScrub: false,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _prevEpisode != null ? 1.0 : 0.0,
                child: Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: _prevEpisode != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEpisodeNavButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: () => _switchToEpisode(_prevEpisode!),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              _buildControlButton(
                icon: Icons.replay_10,
                onTap: () {
                  final newPosition = _position - const Duration(seconds: 10);
                  _seekTo(newPosition < Duration.zero
                      ? Duration.zero
                      : newPosition);
                },
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Icons.forward_10,
                onTap: () {
                  final newPosition = _position + const Duration(seconds: 10);
                  if (newPosition <= _duration) {
                    _seekTo(newPosition);
                  } else {
                    _seekTo(_duration);
                  }
                },
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _nextEpisode != null ? 1.0 : 0.0,
                child: Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: _nextEpisode != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      _buildEpisodeNavButton(
                        icon: Icons.skip_next_rounded,
                        onTap: () => _switchToEpisode(_nextEpisode!),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsbStreamBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _prevEpisode != null ? 1.0 : 0.0,
            child: Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: _prevEpisode != null,
              child: _buildEpisodeNavButton(
                icon: Icons.skip_previous_rounded,
                onTap: () => _switchToEpisode(_prevEpisode!),
              ),
            ),
          ),
          const SizedBox(width: 48),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _nextEpisode != null ? 1.0 : 0.0,
            child: Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: _nextEpisode != null,
              child: _buildEpisodeNavButton(
                icon: Icons.skip_next_rounded,
                onTap: () => _switchToEpisode(_nextEpisode!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildEpisodeNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildBrightnessControl() {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 4,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Container(
                width: 4,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 150 * _brightness,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 4,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Container(
                width: 4,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 150 * (_volume / 100),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
