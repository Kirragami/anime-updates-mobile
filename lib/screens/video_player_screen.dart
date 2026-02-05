import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:async';
import 'dart:io';
import '../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const VideoPlayerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VlcPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isControlsVisible = true;
  bool _isFullscreen = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _controlsTimer;
  double _volume = 100.0;
  double _brightness = 1.0;
  
 
  bool _isVolumeControlVisible = false;
  bool _isBrightnessControlVisible = false;
  bool _isGestureActive = false; 
  double _gestureStartY = 0.0;
  double _initialVolume = 100.0;
  double _initialBrightness = 1.0;

 
  bool _isSeekIndicatorVisible = false;
  String _seekIndicatorText = '';
  DateTime? _lastSeekTime;
  int _consecutiveSeekCount = 0;
  Timer? _seekIndicatorTimer;


  List<DeviceOrientation>? _originalOrientations;

  @override
  void initState() {
    super.initState();

    
    _captureOriginalOrientations();

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
  }
  
  Future<void> _getInitialBrightness() async {
    try {
      final screenBrightness = ScreenBrightness();
      _brightness = await screenBrightness.current ?? 1.0;
    } catch (e) {
      _brightness = 1.0;
    }
  }

  void _captureOriginalOrientations() async {
    
    
    _originalOrientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
  }

  void _initializePlayer() {
    try {

      final file = File(widget.filePath);

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
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _videoPlayerController != null) {
              
              
              _videoPlayerController!.play().catchError((error) {
                
                
              });
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
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _videoPlayerController == null) {
        
        print('[VideoPlayerScreen] Stopping position updates (disposed)');
        timer.cancel();
        return;
      }
      
      _videoPlayerController!.getPosition().then((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
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
        if (mounted) {
          setState(() {
            _isPlaying = playing == true;
          });
        }
      });
    });
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;
    
    if (_isPlaying) {
      _videoPlayerController!.pause();
      _startControlsTimer();
    } else {
      _videoPlayerController!.play();
      _startControlsTimer();
    }
  }

  void _seekTo(Duration position) {
    _videoPlayerController?.seekTo(position);
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
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

  void _handleDoubleTap() {
  
    setState(() {
      _isControlsVisible = true;
    });
    _startControlsTimer();
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

  @override
  void dispose() async {
    _controlsTimer?.cancel();
    _seekIndicatorTimer?.cancel(); 
    _videoPlayerController?.dispose();

   
    SystemChrome.setSystemUIChangeCallback(null);

   
    try {
      final screenBrightness = ScreenBrightness();
      await screenBrightness.resetScreenBrightness();
    } catch (e) {
      print('[VideoPlayerScreen] Error resetting brightness: $e');
    }

  
    if (_originalOrientations != null) {
      SystemChrome.setPreferredOrientations(_originalOrientations!);
    } else {
      
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.space:
                _togglePlayPause();
                break;
              case LogicalKeyboardKey.arrowLeft:
                _rewind();
                break;
              case LogicalKeyboardKey.arrowRight:
                _forward();
                break;
              case LogicalKeyboardKey.arrowUp:
                _adjustVolume(true); 
                break;
              case LogicalKeyboardKey.arrowDown:
                _adjustVolume(false); 
                break;
            }
          }
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _handleDoubleTap,
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

               
                Positioned(
                  left: 0,
                  top: 0,
                  width: MediaQuery.of(context).size.width * 0.4,
                  bottom: 0,
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTapLeft,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),

               
                Positioned(
                  right: 0,
                  top: 0,
                  width: MediaQuery.of(context).size.width * 0.4,
                  bottom: 0,
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTapRight,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
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
                    child: _buildControlsOverlay(),
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          
          
          if (widget.title != null)
            Expanded(
              child: Text(
                widget.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
