import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/active_download.dart';

class ActiveDownloadsManager {
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");
  
  static final ActiveDownloadsManager _instance = ActiveDownloadsManager._internal();
  factory ActiveDownloadsManager() => _instance;
  ActiveDownloadsManager._internal();
  
  final Map<String, ActiveDownload> _activeDownloads = {};
  final ValueNotifier<Map<String, ActiveDownload>> stateNotifier = ValueNotifier({});
  
  Map<String, ActiveDownload> get activeDownloads => Map.unmodifiable(_activeDownloads);
  int get activeCount => _activeDownloads.length;
  bool get hasActiveDownloads => _activeDownloads.isNotEmpty;
  
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
      
    } catch (e) {
      rethrow;
    }
  }
  
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
    }
  }
  
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
      
    } catch (e) {
      rethrow;
    }
  }
  
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
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> resumeDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("resumeTorrent", {"releaseId": releaseId});
      
      if (_activeDownloads.containsKey(releaseId)) {
        _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
          status: ActiveDownloadStatus.downloading,
        );
        _notifyListeners();
      }
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> cancelDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("deleteTorrentFile", {"releaseId": releaseId});
      
      _activeDownloads.remove(releaseId);
      _notifyListeners();
      
    } catch (e) {
      rethrow;
    }
  }
  
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
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> resumeAllDownloads() async {
    try {
      await _channel.invokeMethod("resumeAllTorrents");
      
      for (final key in _activeDownloads.keys) {
        _activeDownloads[key] = _activeDownloads[key]!.copyWith(
          status: ActiveDownloadStatus.downloading,
        );
      }
      _notifyListeners();
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> setDownloadSpeedLimit(int limitKbps) async {
    try {
      await _channel.invokeMethod("setDownloadSpeedLimit", {"speedLimit": limitKbps});
      
    } catch (e) {
      rethrow;
    }
  }
  
  ActiveDownload? getDownload(String releaseId) {
    return _activeDownloads[releaseId];
  }
  
  bool hasDownload(String releaseId) {
    return _activeDownloads.containsKey(releaseId);
  }
  
  List<ActiveDownload> getDownloadsByStatus(ActiveDownloadStatus status) {
    return _activeDownloads.values.where((download) => download.status == status).toList();
  }
  
  void _handleAdded(Map<String, dynamic> torrentData) {
    final activeDownload = ActiveDownload.fromMap(torrentData);
    _activeDownloads[activeDownload.releaseId] = activeDownload;
    
  }
  
  void _handleProgressed(Map<String, dynamic> torrentData) {
    final releaseId = torrentData['releaseId'] as String;
    
    if (_activeDownloads.containsKey(releaseId)) {
      _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
        progress: (torrentData['progress'] as num).toDouble(),
        speed: (torrentData['speed'] as num).toInt(),
        status: ActiveDownloadStatus.downloading,
      );
      
    } else {
      // Handle case where download is not found
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
    
  }

  void _handleResumed(Map<String, dynamic> torrentData) {
    final releaseId = torrentData['releaseId'] as String;
    if (_activeDownloads.containsKey(releaseId)) {
      _activeDownloads[releaseId] = _activeDownloads[releaseId]!.copyWith(
        status: ActiveDownloadStatus.downloading,
        speed: 0,
      );
    }
    
  }
  
  void _handleCompleted(String releaseId) {
    _activeDownloads.remove(releaseId);
    
  }
  
  void _handleDeleted(String releaseId) {
    _activeDownloads.remove(releaseId);
    
  }
  
  void _notifyListeners() {
    stateNotifier.value = Map<String, ActiveDownload>.from(_activeDownloads);
  }
  
  void dispose() {
    stateNotifier.dispose();
  }
}
