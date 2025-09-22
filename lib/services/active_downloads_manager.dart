import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/active_download.dart';

class ActiveDownloadsManager {
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");
  
  // Singleton pattern
  static final ActiveDownloadsManager _instance = ActiveDownloadsManager._internal();
  factory ActiveDownloadsManager() => _instance;
  ActiveDownloadsManager._internal();
  
  // State management
  final Map<String, ActiveDownload> _activeDownloads = {};
  final ValueNotifier<Map<String, ActiveDownload>> stateNotifier = ValueNotifier({});
  
  // Getters
  Map<String, ActiveDownload> get activeDownloads => Map.unmodifiable(_activeDownloads);
  int get activeCount => _activeDownloads.length;
  bool get hasActiveDownloads => _activeDownloads.isNotEmpty;
  
  // Initialize from native managed torrents
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod("startSession");
      
      final List<dynamic> managedResult = await _channel.invokeMethod("getManagedTorrents");
      final List<Map<dynamic, dynamic>> managedTorrents = managedResult.cast<Map<dynamic, dynamic>>();
      
      _activeDownloads.clear();
      
      for (final torrentMap in managedTorrents) {
        torrentMap['status'] = ActiveDownloadStatus.paused.name;
        final activeDownload = ActiveDownload.fromMap(Map<String, dynamic>.from(torrentMap));
        _activeDownloads[activeDownload.releaseId] = activeDownload;
      }
      
      _notifyListeners();
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Initialized with ${_activeDownloads.length} active downloads");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error initializing - $e");
      }
      rethrow;
    }
  }
  
  // Handle events from native
  void handleEvent(String type, Map<String, dynamic> torrentData) {
    try {
      final releaseId = torrentData['releaseId'] as String;
      
      switch (type) {
        case 'added':
          _handleAdded(torrentData);
          break;
        case 'progressed':
          _handleProgressed(torrentData);
          break;
        case 'paused':
          _handlePaused(torrentData);
          break;
        case 'resumed':
          _handleResumed(torrentData);
          break;
        case 'completed':
          _handleCompleted(releaseId);
          break;
        case 'deleted':
          _handleDeleted(releaseId);
          break;
      }
      
      _notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error handling event $type - $e");
      }
    }
  }
  
  // Start a new download
  Future<void> startDownload({
    required String releaseId,
    required String magnetUrl,
    required String fileName,
    required String showName,
    required String episode,
  }) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final savePath = '${directory.path}/TorrentFileDownloads';
      await Directory(savePath).create(recursive: true);
      
      await _channel.invokeMethod("addTorrent", {
        "releaseId": releaseId,
        "magnetUrl": magnetUrl,
        "savePath": savePath,
        "fileName": fileName,
        "showName": showName,
        "episode": episode,
      });
      
      // Create initial active download (will be updated by event)
      final activeDownload = ActiveDownload(
        releaseId: releaseId,
        fileName: fileName,
        showName: showName,
        episode: episode,
        sha1: '',
        progress: 0.0,
        speed: 0,
        status: ActiveDownloadStatus.downloading,
      );
      
      _activeDownloads[releaseId] = activeDownload;
      _notifyListeners();
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Started download for $releaseId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error starting download - $e");
      }
      rethrow;
    }
  }
  
  // Pause download
  Future<void> pauseDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("pauseTorrent", {"releaseId": releaseId});
      
      if (_activeDownloads.containsKey(releaseId)) {
        _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
          status: ActiveDownloadStatus.paused,
          speed: 0,
        );
        _notifyListeners();
      }
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Paused download $releaseId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error pausing download - $e");
      }
      rethrow;
    }
  }
  
  // Resume download
  Future<void> resumeDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("resumeTorrent", {"releaseId": releaseId});
      
      if (_activeDownloads.containsKey(releaseId)) {
        _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
          status: ActiveDownloadStatus.downloading,
        );
        _notifyListeners();
      }
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Resumed download $releaseId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error resuming download - $e");
      }
      rethrow;
    }
  }
  
  // Cancel download
  Future<void> cancelDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("deleteTorrentFile", {"releaseId": releaseId});
      
      _activeDownloads.remove(releaseId);
      _notifyListeners();
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Cancelled download $releaseId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error cancelling download - $e");
      }
      rethrow;
    }
  }
  
  // Pause all downloads
  Future<void> pauseAllDownloads() async {
    try {
      await _channel.invokeMethod("pauseAllTorrents");
      
      for (final key in _activeDownloads.keys) {
        _activeDownloads[key] = _activeDownloads[key]!.copyWith(
          status: ActiveDownloadStatus.paused,
          speed: 0,
        );
      }
      _notifyListeners();
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Paused all downloads");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error pausing all downloads - $e");
      }
      rethrow;
    }
  }
  
  // Resume all downloads
  Future<void> resumeAllDownloads() async {
    try {
      await _channel.invokeMethod("resumeAllTorrents");
      
      for (final key in _activeDownloads.keys) {
        _activeDownloads[key] = _activeDownloads[key]!.copyWith(
          status: ActiveDownloadStatus.downloading,
        );
      }
      _notifyListeners();
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Resumed all downloads");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error resuming all downloads - $e");
      }
      rethrow;
    }
  }
  
  // Set download speed limit
  Future<void> setDownloadSpeedLimit(int limitKbps) async {
    try {
      await _channel.invokeMethod("setDownloadSpeedLimit", {"speedLimit": limitKbps});
      
      if (kDebugMode) {
        print("ActiveDownloadsManager: Set speed limit to ${limitKbps}KB/s");
      }
    } catch (e) {
      if (kDebugMode) {
        print("ActiveDownloadsManager: Error setting speed limit - $e");
      }
      rethrow;
    }
  }
  
  // Get download by release ID
  ActiveDownload? getDownload(String releaseId) {
    return _activeDownloads[releaseId];
  }
  
  // Check if download exists
  bool hasDownload(String releaseId) {
    return _activeDownloads.containsKey(releaseId);
  }
  
  // Get downloads by status
  List<ActiveDownload> getDownloadsByStatus(ActiveDownloadStatus status) {
    return _activeDownloads.values.where((download) => download.status == status).toList();
  }
  
  // Private event handlers
  void _handleAdded(Map<String, dynamic> torrentData) {
    final activeDownload = ActiveDownload.fromMap(torrentData);
    _activeDownloads[activeDownload.releaseId] = activeDownload;
    
    if (kDebugMode) {
      print("ActiveDownloadsManager: Added download ${activeDownload.releaseId}");
    }
  }
  
  void _handleProgressed(Map<String, dynamic> torrentData) {
    final releaseId = torrentData['releaseId'] as String;
    if (kDebugMode) {
      print("ActiveDownloadsManager: Handling progress for releaseId: $releaseId");
      print("  - Raw torrent data: $torrentData");
      print("  - Old progress: ${_activeDownloads[releaseId]?.progress ?? 'N/A'}");
      print("  - New progress: ${torrentData['progress']}");
      print("  - Speed: ${torrentData['speed']}");
    }
    
    if (_activeDownloads.containsKey(releaseId)) {
      _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
        progress: (torrentData['progress'] as num).toDouble(),
        speed: (torrentData['speed'] as num).toInt(),
        status: ActiveDownloadStatus.downloading,
      );
      
      if (kDebugMode) {
        print("  - Updated progress: ${_activeDownloads[releaseId]?.progress}");
      }
    } else {
      if (kDebugMode) {
        print("  - releaseId '$releaseId' not found in active downloads");
        print("  - Active downloads keys: ${_activeDownloads.keys.toList()}");
        print("  - Checking for partial matches...");
        for (String key in _activeDownloads.keys) {
          if (key.contains(releaseId) || releaseId.contains(key)) {
            print("  - Potential match: '$key'");
          }
        }
      }
    }
  }
  
  void _handlePaused(Map<String, dynamic> torrentData) {
    final releaseId = torrentData['releaseId'] as String;
    if (_activeDownloads.containsKey(releaseId)) {
      _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
        status: ActiveDownloadStatus.paused,
        speed: 0,
      );
    }
    
    if (kDebugMode) {
      print("ActiveDownloadsManager: Paused download $releaseId");
    }
  }

  void _handleResumed(Map<String, dynamic> torrentData) {
    final releaseId = torrentData['releaseId'] as String;
    if (_activeDownloads.containsKey(releaseId)) {
      _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
        status: ActiveDownloadStatus.downloading,
        speed: 0,
      );
    }
    
    if (kDebugMode) {
      print("ActiveDownloadsManager: Paused download $releaseId");
    }
  }
  
  void _handleCompleted(String releaseId) {
    _activeDownloads.remove(releaseId);
    
    if (kDebugMode) {
      print("ActiveDownloadsManager: Completed download $releaseId - moved to completed");
    }
  }
  
  void _handleDeleted(String releaseId) {
    _activeDownloads.remove(releaseId);
    
    if (kDebugMode) {
      print("ActiveDownloadsManager: Deleted download $releaseId");
    }
  }
  
  void _notifyListeners() {
    if (kDebugMode) {
      print("ActiveDownloadsManager: Notifying listeners of state change");
      print("  - Active downloads count: ${_activeDownloads.length}");
    }
    stateNotifier.value = Map<String, ActiveDownload>.from(_activeDownloads);
  }
  
  // Cleanup
  void dispose() {
    stateNotifier.dispose();
  }
}
