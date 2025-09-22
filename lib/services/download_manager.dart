// import 'package:flutter/foundation.dart';
// import '../models/anime_item.dart';
// import '../models/download_state.dart';
// import '../models/active_download.dart';
// import '../models/completed_download.dart';
// import 'active_downloads_manager.dart';
// import 'completed_downloads_manager.dart';

// /// Legacy compatibility wrapper for the new download management system
// /// This class provides a unified interface to maintain compatibility with existing code
// /// while using the new separated active/completed download managers underneath
// @Deprecated('Use ActiveDownloadsManager and CompletedDownloadsManager directly')
// class DownloadManager {
//   // Singleton pattern for compatibility
//   static final DownloadManager _instance = DownloadManager._internal();
//   factory DownloadManager() => _instance;
//   DownloadManager._internal();

//   // Manager instances
//   late final ActiveDownloadsManager _activeDownloadsManager;
//   late final CompletedDownloadsManager _completedDownloadsManager;
  
//   // Combined state notifier for backward compatibility
//   final ValueNotifier<Map<String, AnimeItem>> _stateNotifier = ValueNotifier({});
  
//   // Initialize managers
//   void _initializeManagers() {
//     _activeDownloadsManager = ActiveDownloadsManager();
//     _completedDownloadsManager = CompletedDownloadsManager();
    
//     // Listen to both managers and combine their states
//     _activeDownloadsManager.stateNotifier.addListener(_updateCombinedState);
//     _completedDownloadsManager.stateNotifier.addListener(_updateCombinedState);
//   }

//   // Getter for backward compatibility
//   ValueNotifier<Map<String, AnimeItem>> get stateNotifier => _stateNotifier;
//   Map<String, AnimeItem> get releaseStates => _stateNotifier.value;

//   // Initialize release states (legacy method)
//   Future<void> initializeReleaseStates(List<AnimeItem> releases) async {
//     if (kDebugMode) {
//       print("DownloadManager (Legacy): initializeReleaseStates called with ${releases.length} releases");
//       print("This method is deprecated. The new system initializes automatically from native data.");
//     }
    
//     _initializeManagers();
//     _updateCombinedState();
//   }

//   // Start progress listener (legacy method - now no-op)
//   void startProgressListener() {
//     if (kDebugMode) {
//       print("DownloadManager (Legacy): startProgressListener called");
//       print("This method is deprecated. Event listening is handled by DownloadEventDispatcher.");
//     }
    
//     _initializeManagers();
//   }

//   // Download a release (legacy compatibility)
//   Future<void> downloadRelease(AnimeItem release) async {
//     _initializeManagers();
    
//     await _activeDownloadsManager.startDownload(
//       releaseId: release.id,
//       magnetUrl: release.downloadUrl,
//       fileName: release.fileName,
//       showName: release.title,
//       episode: release.episode,
//     );
    
//     if (kDebugMode) {
//       print("DownloadManager (Legacy): Started download for ${release.id}");
//     }
//   }

//   // Pause a release (legacy compatibility)
//   Future<void> pauseRelease(String releaseId) async {
//     _initializeManagers();
//     await _activeDownloadsManager.pauseDownload(releaseId);
//   }

//   // Resume a release (legacy compatibility)
//   Future<void> resumeRelease(String releaseId) async {
//     _initializeManagers();
//     await _activeDownloadsManager.resumeDownload(releaseId);
//   }

//   // Delete a download (legacy compatibility)
//   Future<void> deleteDownload(String releaseId) async {
//     _initializeManagers();
    
//     // Try to cancel from active downloads first
//     if (_activeDownloadsManager.hasDownload(releaseId)) {
//       await _activeDownloadsManager.cancelDownload(releaseId);
//     } else if (_completedDownloadsManager.hasDownload(releaseId)) {
//       await _completedDownloadsManager.deleteDownload(releaseId);
//     }
//   }

//   // Open downloaded file (legacy compatibility)
//   Future<bool> openDownloadedFile(AnimeItem release) async {
//     _initializeManagers();
//     return await _completedDownloadsManager.openFile(release.id);
//   }

//   // Get download state (legacy compatibility)
//   DownloadState getDownloadState(String releaseId) {
//     _initializeManagers();
    
//     if (_activeDownloadsManager.hasDownload(releaseId)) {
//       final activeDownload = _activeDownloadsManager.getDownload(releaseId);
//       if (activeDownload != null) {
//         switch (activeDownload.status) {
//           case ActiveDownloadStatus.downloading:
//             return DownloadState.downloading;
//           case ActiveDownloadStatus.paused:
//             return DownloadState.paused;
//         }
//       }
//     }
    
//     if (_completedDownloadsManager.hasDownload(releaseId)) {
//       return DownloadState.downloaded;
//     }
    
//     return DownloadState.notDownloaded;
//   }

//   // Set download speed limit (legacy compatibility)
//   Future<void> setDownloadSpeedLimit(int limit) async {
//     _initializeManagers();
//     await _activeDownloadsManager.setDownloadSpeedLimit(limit);
//   }

//   // Get progress (legacy compatibility)
//   double getProgress(String releaseId) {
//     _initializeManagers();
    
//     final activeDownload = _activeDownloadsManager.getDownload(releaseId);
//     if (activeDownload != null) {
//       return activeDownload.progress;
//     }
    
//     if (_completedDownloadsManager.hasDownload(releaseId)) {
//       return 100.0;
//     }
    
//     return 0.0;
//   }

//   // Update combined state for backward compatibility
//   void _updateCombinedState() {
//     final Map<String, AnimeItem> combinedState = {};
    
//     // Add active downloads as AnimeItems
//     for (final activeDownload in _activeDownloadsManager.activeDownloads.values) {
//       combinedState[activeDownload.releaseId] = _convertActiveDownloadToAnimeItem(activeDownload);
//     }
    
//     // Add completed downloads as AnimeItems
//     for (final completedDownload in _completedDownloadsManager.completedDownloads.values) {
//       combinedState[completedDownload.releaseId] = _convertCompletedDownloadToAnimeItem(completedDownload);
//     }
    
//     _stateNotifier.value = combinedState;
//   }

//   // Convert ActiveDownload to AnimeItem for compatibility
//   AnimeItem _convertActiveDownloadToAnimeItem(ActiveDownload activeDownload) {
//     return AnimeItem(
//       id: activeDownload.releaseId,
//       title: activeDownload.showName,
//       animeShowId: '', // Not available in ActiveDownload
//       episode: activeDownload.episode,
//       fileName: activeDownload.fileName,
//       downloadUrl: '', // Not available in ActiveDownload
//       releasedDate: DateTime.now(), // Not available in ActiveDownload
//       imageUrl: '', // Not available in ActiveDownload
//       tracked: false, // Not available in ActiveDownload
//       downloadState: activeDownload.status == ActiveDownloadStatus.downloading 
//           ? DownloadState.downloading 
//           : DownloadState.paused,
//       progress: activeDownload.progress,
//     );
//   }

//   // Convert CompletedDownload to AnimeItem for compatibility
//   AnimeItem _convertCompletedDownloadToAnimeItem(CompletedDownload completedDownload) {
//     return AnimeItem(
//       id: completedDownload.releaseId,
//       title: completedDownload.showName,
//       animeShowId: '', // Not available in CompletedDownload
//       episode: completedDownload.episode,
//       fileName: completedDownload.fileName,
//       downloadUrl: '', // Not available in CompletedDownload
//       releasedDate: DateTime.now(), // Not available in CompletedDownload
//       imageUrl: '', // Not available in CompletedDownload
//       tracked: false, // Not available in CompletedDownload
//       downloadState: DownloadState.downloaded,
//       progress: 100.0,
//     );
//   }

//   // Cleanup
//   void dispose() {
//     _stateNotifier.dispose();
//   }
// }