import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'active_downloads_manager.dart';
import 'completed_downloads_manager.dart';

class DownloadEventDispatcher {
  static const _eventChannel = EventChannel('com.aura.anime_updates/torrentEvents');
  
  // Singleton pattern
  static final DownloadEventDispatcher _instance = DownloadEventDispatcher._internal();
  factory DownloadEventDispatcher() => _instance;
  DownloadEventDispatcher._internal();
  
  StreamSubscription? _eventSubscription;
  bool _isListening = false;
  
  // Manager instances
  late final ActiveDownloadsManager _activeDownloadsManager;
  late final CompletedDownloadsManager _completedDownloadsManager;
  
  // Initialize the dispatcher with manager instances
  void initialize() {
    _activeDownloadsManager = ActiveDownloadsManager();
    _completedDownloadsManager = CompletedDownloadsManager();
  }
  
  // Start listening to torrent events
  void startListening() {
    if (_isListening) {
      if (kDebugMode) {
        print("DownloadEventDispatcher: Already listening to events");
      }
      return;
    }
    
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleError,
      onDone: _handleDone,
    );
    
    _isListening = true;
    
    if (kDebugMode) {
      print("DownloadEventDispatcher: Started listening to torrent events");
    }
  }
  
  // Stop listening to torrent events
  void stopListening() {
    if (!_isListening) return;
    
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _isListening = false;
    
    if (kDebugMode) {
      print("DownloadEventDispatcher: Stopped listening to torrent events");
    }
  }
  
  // Restart listening (useful for reconnecting after errors)
  void restartListening() {
    stopListening();
    startListening();
  }
  
  // Check if currently listening
  bool get isListening => _isListening;
  
  // Handle incoming events
  void _handleEvent(dynamic event) {
    try {
      if (kDebugMode) {
        print("=== DownloadEventDispatcher Raw Event ===");
        print("Raw event: $event");
        print("Event type: ${event.runtimeType}");
        if (event is Map) {
          print("Event keys: ${event.keys.toList()}");
        }
      }
      
      if (event is! Map) {
        if (kDebugMode) {
          print("DownloadEventDispatcher: Invalid event format - expected Map, got ${event.runtimeType}");
        }
        return;
      }
      
      final eventMap = Map<String, dynamic>.from(event);
      final type = eventMap['type'] as String?;
      
      // Check for nested structure first (new expected format)
      Map<String, dynamic>? torrentData;
      final managedTorrentRaw = eventMap['managedTorrent'];
      if (managedTorrentRaw != null && managedTorrentRaw is Map) {
        torrentData = Map<String, dynamic>.from(managedTorrentRaw);
      }
      
      // Fallback to flat structure (old working format)
      if (torrentData == null) {
        if (kDebugMode) {
          print("DownloadEventDispatcher: No nested 'managedTorrent', trying flat structure");
        }
        // If it's a flat structure, the event itself contains the torrent data
        if (eventMap.containsKey('releaseId')) {
          torrentData = eventMap;
        }
      }
      
      if (type == null || torrentData == null) {
        if (kDebugMode) {
          print("DownloadEventDispatcher: Invalid event data - missing type or torrent data");
          print("Event: $eventMap");
          print("Available keys: ${eventMap.keys.toList()}");
        }
        return;
      }
      
      if (kDebugMode) {
        print("DownloadEventDispatcher: Received event - type: $type, releaseId: ${torrentData['releaseId']}");
      }
      
      // Route events to appropriate managers
      _routeEvent(type, torrentData);
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("DownloadEventDispatcher: Error handling event - $e");
        print("Stack trace: $stackTrace");
        print("Event data: $event");
      }
    }
  }
  
  // Route events to the appropriate managers
  void _routeEvent(String type, Map<String, dynamic> torrentData) {
    switch (type) {
      case 'added':
        // New download started - add to active downloads
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'progressed':
        // Download progress update - update active download
        if (kDebugMode) {
          print("DownloadEventDispatcher: Progress event - releaseId: ${torrentData['releaseId']}, progress: ${torrentData['progress']}, speed: ${torrentData['speed']}");
        }
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'paused':
        // Download paused - update active download status
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;

      case 'resumed':
        _activeDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'completed':
        // Download completed - remove from active, add to completed
        _activeDownloadsManager.handleEvent(type, torrentData);
        _completedDownloadsManager.handleEvent(type, torrentData);
        break;
        
      case 'deleted':
        // Download deleted - could be from either active or completed
        _activeDownloadsManager.handleEvent(type, torrentData);
        _completedDownloadsManager.handleEvent(type, torrentData);
        break;
        
      default:
        if (kDebugMode) {
          print("DownloadEventDispatcher: Unknown event type: $type");
        }
        break;
    }
  }
  
  // Handle stream errors
  void _handleError(dynamic error) {
    if (kDebugMode) {
      print("DownloadEventDispatcher: Stream error - $error");
    }
    
    _isListening = false;
    
    // Attempt to reconnect after a delay
    Timer(const Duration(seconds: 5), () {
      if (kDebugMode) {
        print("DownloadEventDispatcher: Attempting to reconnect...");
      }
      restartListening();
    });
  }
  
  // Handle stream completion
  void _handleDone() {
    if (kDebugMode) {
      print("DownloadEventDispatcher: Event stream completed");
    }
    
    _isListening = false;
    
    // Attempt to reconnect after a delay
    Timer(const Duration(seconds: 2), () {
      if (kDebugMode) {
        print("DownloadEventDispatcher: Attempting to reconnect after stream completion...");
      }
      restartListening();
    });
  }
  
  // Cleanup
  void dispose() {
    stopListening();
    if (kDebugMode) {
      print("DownloadEventDispatcher: Disposed");
    }
  }
}
