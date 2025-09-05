import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import '../models/anime_item.dart';
import '../models/download_state.dart';

class DownloadManager {
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");
  static const _eventChannel = EventChannel('com.aura.anime_updates/torrentEvents');
  
  // Map to store the current state of all releases
  Map<String, AnimeItem> _releaseStates = {};
  
  // Singleton pattern
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // For notifying UI components of state changes
  final ValueNotifier<Map<String, AnimeItem>> _stateNotifier = ValueNotifier({});

  // Getters
  Map<String, AnimeItem> get releaseStates => _releaseStates;
  ValueNotifier<Map<String, AnimeItem>> get stateNotifier => _stateNotifier;

  // Initialize release states based on completed and managed torrents
  Future<void> initializeReleaseStates(List<AnimeItem> releases) async {
    try {
      if (kDebugMode) {
        print("=== Initializing release states for ${releases.length} releases ===");
      }
      
      // Get completed torrents
      final List<dynamic> completedResult = await _channel.invokeMethod("getCompletedTorrents");
      final List<Map<dynamic, dynamic>> completedTorrents = completedResult.cast<Map<dynamic, dynamic>>();
      
      // Get managed torrents
      final List<dynamic> managedResult = await _channel.invokeMethod("getManagedTorrents");
      final List<Map<dynamic, dynamic>> managedTorrents = managedResult.cast<Map<dynamic, dynamic>>();
      
      if (kDebugMode) {
        print("Completed torrents count: ${completedTorrents.length}");
        print("Managed torrents count: ${managedTorrents.length}");
        print("Completed torrents: $completedTorrents");
        print("Managed torrents: $managedTorrents");
      }
      
      // Create a map for quick lookup
      final Map<String, Map<dynamic, dynamic>> completedMap = {
        for (var torrent in completedTorrents)
          if (torrent['releaseId'] != null) torrent['releaseId'].toString(): torrent
      };
      
      final Map<String, Map<dynamic, dynamic>> managedMap = {
        for (var torrent in managedTorrents)
          if (torrent['uniqueId'] != null) torrent['uniqueId'].toString(): torrent
      };
      
      if (kDebugMode) {
        print("Completed map keys: ${completedMap.keys.toList()}");
        print("Managed map keys: ${managedMap.keys.toList()}");
      }
      
      // Update release states
      for (var release in releases) {
        if (kDebugMode) {
          print("Processing release ${release.id}: ${release.title}");
        }
        
        if (completedMap.containsKey(release.id)) {
          // Release is completed
          if (kDebugMode) {
            print("  -> Release ${release.id} is COMPLETED");
          }
          _releaseStates[release.id] = release.copyWith(
            downloadState: DownloadState.downloaded,
            progress: 100.0
          );
        } else if (managedMap.containsKey(release.id)) {
          // Release is being managed (could be downloading or paused)
          final torrent = managedMap[release.id]!;
          if (kDebugMode) {
            print("  -> Release ${release.id} is MANAGED with progress: ${(torrent['progress'] as num).toDouble()}");
          }
          _releaseStates[release.id] = release.copyWith(
            downloadState: DownloadState.downloading, // Default to downloading, will be updated by events
            progress: (torrent['progress'] as num).toDouble()
          );
        } else {
          // Release is not downloaded
          if (kDebugMode) {
            print("  -> Release ${release.id} is NOT DOWNLOADED");
          }
          _releaseStates[release.id] = release.copyWith(
            downloadState: DownloadState.notDownloaded,
            progress: 0.0
          );
        }
      }
      
      // Notify listeners of state changes
      _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
      
      if (kDebugMode) {
        print("Initialized release states for ${_releaseStates.length} releases");
        for (var entry in _releaseStates.entries) {
          print("  ${entry.key}: state=${entry.value.downloadState}, progress=${entry.value.progress}");
        }
        print("=====================================");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing release states: $e");
      }
    }
  }
  
  // Start listening to progress events
  void startProgressListener() {
    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (kDebugMode) {
          print("=== DownloadManager Event Received ===");
          print("Raw event: $event");
          print("Event type: ${event.runtimeType}");
        }
        
        if (event is Map) {
          final releaseId = event['releaseId'] as String?;
          final progress = (event['progress'] as num?)?.toDouble();
          final status = event['status'] as String?;
          
          if (kDebugMode) {
            print("Parsed event data:");
            print("  releaseId: $releaseId");
            print("  progress: $progress");
            print("  status: $status");
            print("  Available release IDs in state: ${_releaseStates.keys.toList()}");
          }
          
          if (releaseId != null && progress != null) {
            DownloadState state = DownloadState.downloading;
            if (status == "completed") {
              state = DownloadState.downloaded;
              if (kDebugMode) {
                print(">>> COMPLETION EVENT DETECTED for release: $releaseId <<<");
              }
            } else if (status == "paused") {
              state = DownloadState.paused;
              if (kDebugMode) {
                print(">>> PAUSE EVENT DETECTED for release: $releaseId <<<");
              }
            } else if (status == "downloading") {
              state = DownloadState.downloading;
              if (kDebugMode) {
                print(">>> DOWNLOADING EVENT DETECTED for release: $releaseId <<<");
              }
            } else {
              if (kDebugMode) {
                print(">>> UNKNOWN STATUS '$status' for release: $releaseId <<<");
              }
            }
            
            // Update or create the release state
            if (_releaseStates.containsKey(releaseId)) {
              final oldState = _releaseStates[releaseId]?.downloadState;
              final oldProgress = _releaseStates[releaseId]?.progress;
              
              _releaseStates[releaseId] = _releaseStates[releaseId]!.copyWith(
                downloadState: state,
                progress: progress
              );
              
              final newState = _releaseStates[releaseId]?.downloadState;
              final newProgress = _releaseStates[releaseId]?.progress;
              
              if (kDebugMode) {
                print("State update for release $releaseId:");
                print("  Old state: $oldState");
                print("  New state: $newState");
                print("  Old progress: $oldProgress");
                print("  New progress: $newProgress");
                print("  State changed: ${oldState != newState}");
                print("  Progress changed: ${oldProgress != newProgress}");
              }
            } else {
              // If we don't have this release in our states yet, we might want to handle this case
              // For now, we'll just ignore it
              if (kDebugMode) {
                print("WARNING: Received progress update for unknown release: $releaseId");
                print("Known releases: ${_releaseStates.keys.toList()}");
              }
            }
            
            // Notify listeners of state changes
            // Create a completely new map to ensure ValueNotifier detects the change
            _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
            
            if (kDebugMode) {
              print("Notified listeners of state changes for release $releaseId");
              print("Current state notifier value length: ${_stateNotifier.value.length}");
              print("=====================================");
            }
          } else {
            if (kDebugMode) {
              print("ERROR: Invalid event data - missing releaseId or progress");
              print("=====================================");
            }
          }
        } else {
          if (kDebugMode) {
            print("ERROR: Invalid event format: $event");
            print("Expected Map, got: ${event.runtimeType}");
            print("=====================================");
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print("ERROR: Error receiving progress: $error");
        }
      },
    );
  }
  
  // Download a release
  Future<void> downloadRelease(AnimeItem release) async {
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
      
      // Ensure the save path exists
      await Directory(savePath).create(recursive: true);
      
      await _channel.invokeMethod("addTorrent", {
        "releaseId": release.id,
        "magnetUrl": release.downloadUrl,
        "savePath": savePath,
        "fileName": release.fileName
      });
      
      _releaseStates[release.id] = release.copyWith(
        downloadState: DownloadState.downloading,
        progress: 0.0
      );
      
      // Notify listeners of state changes
      _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
      
      if (kDebugMode) {
        print("Started download for release: ${release.id}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error downloading release: $e");
      }
      rethrow;
    }
  }
  
  // Pause a release
  Future<void> pauseRelease(String releaseId) async {
    try {
      await _channel.invokeMethod("pauseTorrent", {
        "releaseId": releaseId
      });
      
      if (_releaseStates.containsKey(releaseId)) {
        _releaseStates[releaseId] = _releaseStates[releaseId]!.copyWith(
          downloadState: DownloadState.paused
        );
        
        // Notify listeners of state changes
        _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
        
        if (kDebugMode) {
          print("Paused release: $releaseId");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error pausing release: $e");
      }
      rethrow;
    }
  }
  
  // Resume a release
  Future<void> resumeRelease(String releaseId) async {
    try {
      await _channel.invokeMethod("resumeTorrent", {
        "releaseId": releaseId
      });
      
      if (_releaseStates.containsKey(releaseId)) {
        _releaseStates[releaseId] = _releaseStates[releaseId]!.copyWith(
          downloadState: DownloadState.downloading
        );
        
        // Notify listeners of state changes
        _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
        
        if (kDebugMode) {
          print("Resumed release: $releaseId");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error resuming release: $e");
      }
      rethrow;
    }
  }
  
  // Delete a downloaded release
  Future<void> deleteDownload(AnimeItem release) async {
    try {
      await _channel.invokeMethod("deleteTorrent", {
        "releaseId": release.id
      });
      
      // Update state
      _releaseStates[release.id] = release.copyWith(
        downloadState: DownloadState.notDownloaded,
        progress: 0.0
      );
      
      // Notify listeners of state changes
      _stateNotifier.value = Map<String, AnimeItem>.from(_releaseStates);
      
      if (kDebugMode) {
        print("Deleted download for release: ${release.id}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting download for release ${release.id}: $e");
      }
      rethrow;
    }
  }
  
  // Open a downloaded release
  Future<bool> openDownloadedFile(AnimeItem release) async {
    try {
      final result = await _channel.invokeMethod("openTorrent", {
        "releaseId": release.id
      });
      
      if (kDebugMode) {
        print("Opened download for release: ${release.id}");
      }
      
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print("Error opening download for release ${release.id}: $e");
      }
      return false;
    }
  }
  
  // Get the download state of a release
  DownloadState getDownloadState(String releaseId) {
    return _releaseStates[releaseId]?.downloadState ?? DownloadState.notDownloaded;
  }
}