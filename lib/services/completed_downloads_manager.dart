import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/completed_download.dart';

class CompletedDownloadsManager {
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");
  
  // Singleton pattern
  static final CompletedDownloadsManager _instance = CompletedDownloadsManager._internal();
  factory CompletedDownloadsManager() => _instance;
  CompletedDownloadsManager._internal();
  
  // State management
  final Map<String, CompletedDownload> _completedDownloads = {};
  final ValueNotifier<Map<String, CompletedDownload>> stateNotifier = ValueNotifier({});
  
  // Getters
  Map<String, CompletedDownload> get completedDownloads => Map.unmodifiable(_completedDownloads);
  int get completedCount => _completedDownloads.length;
  bool get hasCompletedDownloads => _completedDownloads.isNotEmpty;
  
  // Initialize from native completed torrents
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
      
      if (kDebugMode) {
        print("CompletedDownloadsManager: Initialized with ${_completedDownloads.length} completed downloads");
      }
    } catch (e) {
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error initializing - $e");
      }
      rethrow;
    }
  }
  
  // Handle events from native
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
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error handling event $type - $e");
      }
    }
  }
  
  // Open a completed download file
  Future<bool> openFile(String releaseId) async {
    try {
      final download = _completedDownloads[releaseId];
      if (download == null) {
        if (kDebugMode) {
          print("CompletedDownloadsManager: Download not found for $releaseId");
        }
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
        if (kDebugMode) {
          print("CompletedDownloadsManager: File not found at $filePath");
        }
        return false;
      }
      
      final _OpenTypeHint typeHint = _inferOpenTypeFromPath(filePath);
      final result = await OpenFile.open(
        filePath,
        type: typeHint.mimeType,
      );
      final success = result.type == ResultType.done;
      
      if (kDebugMode) {
        print("CompletedDownloadsManager: ${success ? 'Successfully opened' : 'Failed to open'} file $filePath");
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error opening file - $e");
      }
      return false;
    }
  }
  
  // Delete a completed download
  Future<void> deleteDownload(String releaseId) async {
    try {
      await _channel.invokeMethod("deleteTorrentFile", {"releaseId": releaseId});
      
      _completedDownloads.remove(releaseId);
      _notifyListeners();
      
      if (kDebugMode) {
        print("CompletedDownloadsManager: Deleted completed download $releaseId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error deleting download - $e");
      }
      rethrow;
    }
  }
  
  // Check if file exists on disk
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
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error checking file existence - $e");
      }
      return false;
    }
  }
  
  // Get file size
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
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error getting file size - $e");
      }
      return null;
    }
  }
  
  // Get file path
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
      if (kDebugMode) {
        print("CompletedDownloadsManager: Error getting file path - $e");
      }
      return null;
    }
  }
  
  // Get download by release ID
  CompletedDownload? getDownload(String releaseId) {
    return _completedDownloads[releaseId];
  }
  
  // Check if download exists
  bool hasDownload(String releaseId) {
    return _completedDownloads.containsKey(releaseId);
  }
  
  // Get downloads by show name
  List<CompletedDownload> getDownloadsByShow(String showName) {
    return _completedDownloads.values
        .where((download) => download.showName.toLowerCase().contains(showName.toLowerCase()))
        .toList();
  }
  
  // Get all downloads sorted by show name
  List<CompletedDownload> getAllDownloadsSorted() {
    final downloads = _completedDownloads.values.toList();
    downloads.sort((a, b) => a.showName.compareTo(b.showName));
    return downloads;
  }
  
  // Private event handlers
  void _handleCompleted(Map<String, dynamic> torrentData) {
    final completedDownload = CompletedDownload.fromMap(torrentData);
    _completedDownloads[completedDownload.releaseId] = completedDownload;
    
    if (kDebugMode) {
      print("CompletedDownloadsManager: Added completed download ${completedDownload.releaseId}");
    }
  }
  
  void _handleDeleted(String releaseId) {
    _completedDownloads.remove(releaseId);
    
    if (kDebugMode) {
      print("CompletedDownloadsManager: Deleted completed download $releaseId");
    }
  }
  
  void _notifyListeners() {
    stateNotifier.value = Map<String, CompletedDownload>.from(_completedDownloads);
  }
  
  // Cleanup
  void dispose() {
    stateNotifier.dispose();
  }
}

// Helper: Determine appropriate MIME type (Android) from a file path
_OpenTypeHint _inferOpenTypeFromPath(String filePath) {
  final String lower = filePath.toLowerCase();

  // Common video extensions
  const List<String> videoExts = [
    '.mp4', '.mkv', '.webm', '.avi', '.m4v', '.3gp', '.mov', '.flv', '.ts', '.mpeg', '.mpg'
  ];

  for (final ext in videoExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'video/*');
    }
  }

  // Audio extensions (in case some downloads are audio-only)
  const List<String> audioExts = [
    '.mp3', '.aac', '.m4a', '.flac', '.wav', '.ogg', '.opus'
  ];
  for (final ext in audioExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'audio/*');
    }
  }

  // Subtitles and text
  const List<String> subtitleExts = ['.srt', '.ass', '.vtt'];
  for (final ext in subtitleExts) {
    if (lower.endsWith(ext)) {
      return const _OpenTypeHint(mimeType: 'text/plain');
    }
  }

  // Default: let the platform resolve
  return const _OpenTypeHint();
}

class _OpenTypeHint {
  final String? mimeType; // Android/Linux/Windows
  const _OpenTypeHint({this.mimeType});
}
