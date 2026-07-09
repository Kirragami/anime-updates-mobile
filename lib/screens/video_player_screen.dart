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
  double _volume = 100.0;
  double _brightness = 1.0;

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

  StreamSubscription<SyncAction>? _partyActionSub;
  bool _applyingRemoteSync = false;
  bool _partyInitialized = false;
  String? _loadedPartyVideoUrl;
  bool _watchPartyExitHandled = false;
  bool _periodicSyncPending = false;
  Timer? _partySeekDebounce;
  Timer? _partyPlaybackSyncTimer;
  SyncAction? _pendingRemoteSync;

  bool get _watchPartyActive =>
      widget.watchPartyEnabled && ref.read(watchPartyProvider).isActive;

  bool get _isPartyLeader =>
      _watchPartyActive && ref.read(watchPartyProvider).isLeader;

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

  void _resolveAdjacentEpisodes() {
    final currentId = _activeReleaseId;
    if (currentId == null) return;

    final manager = CompletedDownloadsManager();
    final all = manager.completedDownloads.values.toList();

    CompletedDownload? current;
    try {
      current = all.firstWhere((e) => e.releaseId == currentId);
    } catch (_) {
      return;
    }

    final showKey = current.animeShowId ?? current.showName;
    final siblings = all.where((e) {
      final key = e.animeShowId ?? e.showName;
      return key == showKey;
    }).toList();

    final currentNum = _extractEpisodeNumber(current.episode);
    if (currentNum == null) return;

    final numbered = siblings
        .map((e) => MapEntry(_extractEpisodeNumber(e.episode), e))
        .where((e) => e.key != null)
        .toList()
      ..sort((a, b) => a.key!.compareTo(b.key!));

    CompletedDownload? prev;
    CompletedDownload? next;
    for (final entry in numbered) {
      if (entry.key! < currentNum) prev = entry.value;
      if (entry.key! > currentNum && next == null) next = entry.value;
    }

    if (mounted) {
      setState(() {
        _prevEpisode = prev;
        _nextEpisode = next;
      });
    }
  }

  Future<void> _switchToEpisode(CompletedDownload episode) async {
    final manager = CompletedDownloadsManager();
    final filePath = await manager.getFilePath(episode.releaseId);
    if (filePath == null || !mounted) return;

    if (_isPartyLeader) {
      ref.read(watchPartyProvider.notifier).notifyLoadVideo(episode.releaseId);
      _loadedPartyVideoUrl = WatchPartyVideoRef(episode.releaseId).encode();
    }

    _positionTimer?.cancel();
    _positionTimer = null;

    final old = _videoPlayerController;
    setState(() {
      _videoPlayerController = null;
      _isInitialized = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _autoAdvancedCalled = false;
    });

    try { await old?.stop(); }    catch (_) {}
    try { await old?.dispose(); } catch (_) {}

    if (!mounted) return;

    setState(() {
      _activeFilePath = filePath;
      _activeTitle = '${episode.showName} - Episode ${episode.episode}';
      _activeReleaseId = episode.releaseId;
    });

    _resolveAdjacentEpisodes();

    _initializePlayer();
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

    SystemChrome.setSystemUIChangeCallback((bool isSystemOverlaysVisible) async {
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
    _positionTimer?.cancel();
    _positionTimer = null;

    final old = _videoPlayerController;
    setState(() {
      _videoPlayerController = null;
      _isInitialized = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _autoAdvancedCalled = false;
      _partyInitialized = false;
    });

    try { await old?.stop(); } catch (_) {}
    try { await old?.dispose(); } catch (_) {}

    if (!mounted) return;

    final download = manager.completedDownloads[releaseId];
    setState(() {
      _activeFilePath = filePath;
      _activeTitle = download == null
          ? 'Watch party'
          : '${download.showName} - Episode ${download.episode}';
      _activeReleaseId = releaseId;
    });

    _resolveAdjacentEpisodes();
    _initializePlayer(initialSeekSeconds: 0, autoPlay: false);
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
    if (_videoPlayerController == null || !_isInitialized) {
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
    if (!_isPartyLeader || _videoPlayerController == null || !_isInitialized) {
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
    if (_videoPlayerController == null || !_isInitialized) return;

    _applyingRemoteSync = true;
    try {
      final target = Duration(milliseconds: (timestampSeconds * 1000).round());
      final drift = (_position - target).inMilliseconds.abs();
      if (drift > seekThresholdMs) {
        await _videoPlayerController!.seekTo(target);
        if (mounted) {
          setState(() => _position = target);
        }
      }

      if (shouldPlay && !_isPlaying) {
        await _videoPlayerController!.play();
      } else if (!shouldPlay && _isPlaying) {
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
    if (!_watchPartyActive || _isPartyLeader || !_isInitialized) return;
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

  void _initializePlayer({
    double? initialSeekSeconds,
    bool? autoPlay,
  }) {
    try {

      final file = File(_activeFilePath);

      final fileUri = file.uri.toString();
      print('[VideoPlayerScreen] Using file URI: $fileUri');

      _videoPlayerController = VlcPlayerController.file(
        file,
        hwAcc: HwAcc.full,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(2000),
          ]),
          subtitle: VlcSubtitleOptions([
            VlcSubtitleOptions.boldStyle(true),
            VlcSubtitleOptions.fontSize(20),
            VlcSubtitleOptions.color(VlcSubtitleColor.white),
          ]),
        ),
      );

      _videoPlayerController!.addOnInitListener(() {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted && _videoPlayerController != null) {
              final shouldAutoPlay = autoPlay ??
                  (!_watchPartyActive || _isPartyLeader);

              if (initialSeekSeconds != null) {
                await _videoPlayerController!
                    .seekTo(Duration(milliseconds: (initialSeekSeconds * 1000).round()));
              } else {
                final showId = _getAnimeShowId();
                if (showId != null && _activeReleaseId != null && !_watchPartyActive) {
                  final lastPos = PlaybackProgressManager().getPosition(showId, _activeReleaseId!);
                  if (lastPos > 0) {
                    await _videoPlayerController!.seekTo(Duration(seconds: lastPos));
                  }
                }
              }

              if (shouldAutoPlay) {
                await _videoPlayerController!.play().then((_) {
                  if (mounted) _startControlsTimer();
                }).catchError((error) {
                });
              }

              if (_watchPartyActive && !_partyInitialized) {
                _partyInitialized = true;
                if (_isPartyLeader) {
                  _loadedPartyVideoUrl =
                      WatchPartyVideoRef(_activeReleaseId ?? '').encode();
                } else {
                  WatchPartyNavigation.markMemberInPartyPlayer(true);
                  ref
                      .read(watchPartyProvider.notifier)
                      .sendSync(const SyncAction(action: SyncActionType.syncRequest));
                  _startPartyPlaybackSync();
                }
              }

              _flushPendingRemoteSync();
            }
          });
          
          _startPositionUpdates();
        }
      });
    } catch (e, stackTrace) {
      
      print('[VideoPlayerScreen] Error initializing video player: $e');
      
      print('[VideoPlayerScreen] Stack trace: $stackTrace');
    }
  }

  void _startPositionUpdates() {
  
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _videoPlayerController == null) {
        timer.cancel();
        _positionTimer = null;
        return;
      }

      _videoPlayerController!.getPosition().then((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
          
          if (_isPlaying && position.inSeconds > 0) {
            final showId = _getAnimeShowId();
            if (showId != null && _activeReleaseId != null) {
              String? episode;
              try {
                final manager = CompletedDownloadsManager();
                final download = manager.completedDownloads[_activeReleaseId!];
                episode = download?.episode;
              } catch (_) {}

              PlaybackProgressManager().saveProgress(
                showId, 
                _activeReleaseId!, 
                position.inSeconds,
                episode: episode,
              );
            }
          }
        }
      });

      _videoPlayerController!.getDuration().then((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _videoPlayerController!.isPlaying().then((playing) {
        if (!mounted) return;
        
        bool wasPlaying = _isPlaying;
        setState(() {
          _isPlaying = playing == true;
        });

        if (!wasPlaying && _isPlaying && _isControlsVisible) {
          _startControlsTimer();
        }

        if (playing == false &&
            !_autoAdvancedCalled &&
            _nextEpisode != null &&
            _duration.inSeconds > 0 &&
            _position.inSeconds > 0 &&
            (_duration - _position).inSeconds.abs() <= 5) {
          _autoAdvancedCalled = true;
          timer.cancel();
          _positionTimer = null;
          _switchToEpisode(_nextEpisode!);
        }
      });
    });
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;
    
    if (_isPlaying) {
      _videoPlayerController!.pause();
      _emitPartyPlayState(playing: false);
      _startControlsTimer();
    } else {
      _videoPlayerController!.play();
      _emitPartyPlayState(playing: true);
      _startControlsTimer();
    }
  }

  void _seekTo(Duration position) {
    _videoPlayerController?.seekTo(position);
    if (mounted) {
      setState(() => _position = position);
    }
    _emitPartySeek(at: position);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => AppOrientationSystemUi.sync());
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
    if (_lastSeekTime != null && now.difference(_lastSeekTime!).inMilliseconds < 1000) {

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

    _partyActionSub?.cancel();
    _partySeekDebounce?.cancel();
    _stopPartyPlaybackSync();
    _controlsTimer?.cancel();
    _positionTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _videoPlayerController?.dispose();
    _focusNode.dispose();
    _resetBrightness();

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
                  child: _videoPlayerController != null
                      ? VlcPlayer(
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _seekIndicatorText.startsWith('-') ? Icons.replay : Icons.forward,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.55)),
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? _position.inMilliseconds.toDouble()
                        : 0.0,
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 100.0,
                    onChanged: (value) {
                      _seekTo(Duration(milliseconds: value.toInt()));
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
                  _seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
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
