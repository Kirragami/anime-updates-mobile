import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'active_downloads_manager.dart';
import 'completed_downloads_manager.dart';

class DownloadEventDispatcher {
  static const _eventChannel = EventChannel('com.aura.anime_updates/torrentEvents');
  
  static final DownloadEventDispatcher _instance = DownloadEventDispatcher._internal();
  factory DownloadEventDispatcher() => _instance;
  DownloadEventDispatcher._internal();
  
  StreamSubscription? _eventSubscription;
  bool _isListening = false;
  
  late final ActiveDownloadsManager _activeDownloadsManager;
  late final CompletedDownloadsManager _completedDownloadsManager;
  
  void initialize() {
    _activeDownloadsManager = ActiveDownloadsManager();
    _completedDownloadsManager = CompletedDownloadsManager();
  }
  
  void startListening() {
    if (_isListening) {
      return;
    }
    
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleError,
      onDone: _handleDone,
    );
    
    _isListening = true;
    
  }
  
  void stopListening() {
    if (!_isListening) return;
    
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _isListening = false;
    
  }
  
  void restartListening() {
    stopListening();
    startListening();
  }
  
  bool get isListening => _isListening;
  
  void _handleEvent(dynamic event) {
    try {
      if (event is! Map) {
        return;
      }
      
      final eventMap = Map<String, dynamic>.from(event);
      final type = eventMap['type'] as String?;
      
      Map<String, dynamic>? torrentData;
      final managedTorrentRaw = eventMap['managedTorrent'];
      if (managedTorrentRaw != null && managedTorrentRaw is Map) {
        torrentData = Map<String, dynamic>.from(managedTorrentRaw);
      }
      
      if (torrentData == null) {
        if (eventMap.containsKey('releaseId')) {
          torrentData = eventMap;
        }
      }
      
      if (type == null || torrentData == null) {
        return;
      }
      
      
      _routeEvent(type, torrentData);
      
    } catch (e, stackTrace) {
    }
  }
  
  void _routeEvent(String type, Map<String, dynamic> torrentData) {
    switch (type) {
      case 'added':
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'progressed':
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'paused':
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;

      case 'resumed':
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'completed':
        _activeDownloadsManager.handleEvent(type, torrentData);
        _completedDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'deleted':
        _activeDownloadsManager.handleEvent(type, torrentData);
        _completedDownloadsManager.handleEvent(type, torrentData);
        break;
        
      default:
        break;
    }
  }
  
  void _handleError(dynamic error) {
    
    _isListening = false;
    
    Timer(const Duration(seconds: 5), () {
      restartListening();
    });
  }
  
  void _handleDone() {
    
    _isListening = false;
    
    Timer(const Duration(seconds: 2), () {
      restartListening();
    });
  }
  
  void dispose() {
    stopListening();
  }
}
