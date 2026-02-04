import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/completed_download.dart';

class CompletedDownloadsManager {
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");
  
  
  static final CompletedDownloadsManager _instance = CompletedDownloadsManager._internal();
  factory CompletedDownloadsManager() => _instance;
  CompletedDownloadsManager._internal();
  
  
  final Map<String, CompletedDownload> _completedDownloads = {};
  final ValueNotifier<Map<String, CompletedDownload>> stateNotifier = ValueNotifier({});
  
  
  Map<String, CompletedDownload> get completedDownloads => Map.unmodifiable(_completedDownloads);
  int get completedCount => _completedDownloads.length;
  bool get hasCompletedDownloads => _completedDownloads.isNotEmpty;
  
  
  Future<void> initialize() async {
    try {
      final List<dynamic> completedResult = await _channel.invokeMethod("getCompletedTorrents");
      final List<Map<dynamic, dynamic>> completedTorrents = completedResult.cast<Map<dynamic, dynamic>>();
      
      _completedDownloads.clear();
      
      for (final torrentMap in completedTorrents) {
        final completedDownload = CompletedDownload.fromMap(Map<String, dynamic>.from(torrentMap));
        _completedDownloads[completedDownload.releaseId] = completedDownload;
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
        case 'completed':
          _handleCompleted(torrentData);
          break;
        case 'deleted':
          _handleDeleted(releaseId);
          break;
      }
      
      _notifyListeners();
    } catch (e) {
    }
  }
  
  
  Future<bool> openFile(String releaseId) async {
    try {
      final download = _completedDownloads[releaseId];
      if (download == null) {
        return false;
      }
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final filePath = '${directory.path}/TorrentFileDownloads/${download.fileName}';
      final file = File(filePath);
      
      if (!await file.exists()) {
        return false;
      }
      
      final _OpenTypeHint typeHint = _inferOpenTypeFromPath(filePath);
      final result = await OpenFile.open(
        filePath,
        type: typeHint.mimeType,
      );
      final success = result.type == ResultType.done;
      
      
      return success;
    } catch (e) {
      return false;
    }
  }
  
  
  Future<void> deleteDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("deleteTorrentFile", {"releaseId": releaseId});
      
      _completedDownloads.remove(releaseId);
      _notifyListeners();
      
    } catch (e) {
      rethrow;
    }
  }
  
  
  Future<bool> fileExists(String releaseId) async {
    try {
      final download = _completedDownloads[releaseId];
      if (download == null) return false;
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final filePath = '${directory.path}/TorrentFileDownloads/${download.fileName}';
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }
  
  
  Future<int?> getFileSize(String releaseId) async {
    try {
      final download = _completedDownloads[releaseId];
      if (download == null) return null;
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final filePath = '${directory.path}/TorrentFileDownloads/${download.fileName}';
      final file = File(filePath);
      
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  
  Future<String?> getFilePath(String releaseId) async {
    try {
      final download = _completedDownloads[releaseId];
      if (download == null) return null;
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      return '${directory.path}/TorrentFileDownloads/${download.fileName}';
    } catch (e) {
      return null;
    }
  }
  
  
  CompletedDownload? getDownload(String releaseId) {
    return _completedDownloads[releaseId];
  }
  
  
  bool hasDownload(String releaseId) {
    return _completedDownloads.containsKey(releaseId);
  }
  
  
  List<CompletedDownload> getDownloadsByShow(String showName) {
    return _completedDownloads.values
        .where((download) => download.showName.toLowerCase().contains(showName.toLowerCase()))
        .toList();
  }
  
  
  List<CompletedDownload> getAllDownloadsSorted() {
    final downloads = _completedDownloads.values.toList();
    downloads.sort((a, b) => a.showName.compareTo(b.showName));
    return downloads;
  }
  
  Future<String?> getAnimeImagePath(String animeShowId) async {
    try {
      if (animeShowId.isEmpty) return null;
      final String? imagePath = await _channel.invokeMethod("getAnimeImagePath", {
        "animeShowId": animeShowId,
      });
      return imagePath;
    } catch (e) {
      return null;
    }
  }
  
  Map<String, List<CompletedDownload>> getDownloadsGroupedByShowId() {
    final Map<String, List<CompletedDownload>> grouped = {};
    for (final download in _completedDownloads.values) {
      final showId = download.animeShowId ?? download.showName;
      if (!grouped.containsKey(showId)) {
        grouped[showId] = [];
      }
      grouped[showId]!.add(download);
    }
    return grouped;
  }
  
  
  void _handleCompleted(Map<String, dynamic> torrentData) {
    final completedDownload = CompletedDownload.fromMap(torrentData);
    _completedDownloads[completedDownload.releaseId] = completedDownload;
    
  }
  
  void _handleDeleted(String releaseId) {
    _completedDownloads.remove(releaseId);
    
  }
  
  void _notifyListeners() {
    stateNotifier.value = Map<String, CompletedDownload>.from(_completedDownloads);
  }
  
  
  void dispose() {
    stateNotifier.dispose();
  }
}


_OpenTypeHint _inferOpenTypeFromPath(String filePath) {
  final String lower = filePath.toLowerCase();

  
  const List<String> videoExts = [
    '.mp4', '.mkv', '.webm', '.avi', '.m4v', '.3gp', '.mov', '.flv', '.ts', '.mpeg', '.mpg'
  ];

  for (final ext in videoExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'video/*');
    }
  }

  
  const List<String> audioExts = [
    '.mp3', '.aac', '.m4a', '.flac', '.wav', '.ogg', '.opus'
  ];
  for (final ext in audioExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'audio/*');
    }
  }

  
  const List<String> subtitleExts = ['.srt', '.ass', '.vtt'];
  for (final ext in subtitleExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'text/plain');
    }
  }

  
  return const _OpenTypeHint();
}

class _OpenTypeHint {
  final String? mimeType; 
  const _OpenTypeHint({this.mimeType});
}
