import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_download.dart';
import '../models/completed_download.dart';
import '../services/active_downloads_manager.dart';
import '../services/completed_downloads_manager.dart';

// Provider for active downloads
final activeDownloadsProvider = StateNotifierProvider<ActiveDownloadsNotifier, Map<String, ActiveDownload>>((ref) {
  return ActiveDownloadsNotifier();
});

class ActiveDownloadsNotifier extends StateNotifier<Map<String, ActiveDownload>> {
  final ActiveDownloadsManager _manager = ActiveDownloadsManager();
  
  ActiveDownloadsNotifier() : super({}) {
    // Listen to the manager's state changes
    _manager.stateNotifier.addListener(_onStateChanged);
    // Initialize with current state
    state = _manager.activeDownloads;
  }
  
  void _onStateChanged() {
    if (kDebugMode) {
      print("ActiveDownloadsNotifier: State changed - ${_manager.activeDownloads.length} active downloads");
    }
    state = _manager.activeDownloads;
  }
  
  Future<void> startDownload({
    required String releaseId,
    required String magnetUrl,
    required String fileName,
    required String showName,
    required String episode,
  }) async {
    await _manager.startDownload(
      releaseId: releaseId,
      magnetUrl: magnetUrl,
      fileName: fileName,
      showName: showName,
      episode: episode,
    );
  }
  
  Future<void> pauseDownload(String releaseId) async {
    await _manager.pauseDownload(releaseId);
  }
  
  Future<void> resumeDownload(String releaseId) async {
    await _manager.resumeDownload(releaseId);
  }
  
  Future<void> cancelDownload(String releaseId) async {
    await _manager.cancelDownload(releaseId);
  }
  
  Future<void> pauseAllDownloads() async {
    await _manager.pauseAllDownloads();
  }
  
  Future<void> resumeAllDownloads() async {
    await _manager.resumeAllDownloads();
  }
  
  Future<void> setDownloadSpeedLimit(int limitKbps) async {
    await _manager.setDownloadSpeedLimit(limitKbps);
  }
  
  @override
  void dispose() {
    _manager.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }
}

// Provider for completed downloads
final completedDownloadsProvider = StateNotifierProvider<CompletedDownloadsNotifier, Map<String, CompletedDownload>>((ref) {
  return CompletedDownloadsNotifier();
});

class CompletedDownloadsNotifier extends StateNotifier<Map<String, CompletedDownload>> {
  final CompletedDownloadsManager _manager = CompletedDownloadsManager();
  
  CompletedDownloadsNotifier() : super({}) {
    // Listen to the manager's state changes
    _manager.stateNotifier.addListener(_onStateChanged);
    // Initialize with current state
    state = _manager.completedDownloads;
  }
  
  void _onStateChanged() {
    state = _manager.completedDownloads;
  }
  
  Future<bool> openFile(String releaseId) async {
    return await _manager.openFile(releaseId);
  }
  
  Future<void> deleteDownload(String releaseId) async {
    await _manager.deleteDownload(releaseId);
  }
  
  Future<bool> fileExists(String releaseId) async {
    return await _manager.fileExists(releaseId);
  }
  
  Future<int?> getFileSize(String releaseId) async {
    return await _manager.getFileSize(releaseId);
  }
  
  Future<String?> getFilePath(String releaseId) async {
    return await _manager.getFilePath(releaseId);
  }
  
  List<CompletedDownload> getDownloadsByShow(String showName) {
    return _manager.getDownloadsByShow(showName);
  }
  
  List<CompletedDownload> getAllDownloadsSorted() {
    return _manager.getAllDownloadsSorted();
  }
  
  @override
  void dispose() {
    _manager.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }
}

// Helper provider to get download status for a specific release
final downloadStatusProvider = Provider.family<DownloadStatus, String>((ref, releaseId) {
  final activeDownloads = ref.watch(activeDownloadsProvider);
  final completedDownloads = ref.watch(completedDownloadsProvider);
  
  final activeDownload = activeDownloads[releaseId];
  final completedDownload = completedDownloads[releaseId];
  
  if (activeDownload != null) {
    return DownloadStatus(
      isActive: true,
      isCompleted: false,
      progress: activeDownload.progress,
      status: activeDownload.status,
      speed: activeDownload.speed,
    );
  } else if (completedDownload != null) {
    return DownloadStatus(
      isActive: false,
      isCompleted: true,
      progress: 100.0,
      status: ActiveDownloadStatus.downloading, // Not relevant for completed
      speed: 0,
    );
  } else {
    return DownloadStatus(
      isActive: false,
      isCompleted: false,
      progress: 0.0,
      status: ActiveDownloadStatus.downloading, // Not relevant
      speed: 0,
    );
  }
});

// Helper class to represent download status
class DownloadStatus {
  final bool isActive;
  final bool isCompleted;
  final double progress;
  final ActiveDownloadStatus status;
  final int speed;
  
  const DownloadStatus({
    required this.isActive,
    required this.isCompleted,
    required this.progress,
    required this.status,
    required this.speed,
  });
  
  bool get isDownloading => isActive && status == ActiveDownloadStatus.downloading;
  bool get isPaused => isActive && status == ActiveDownloadStatus.paused;
  bool get isNotDownloaded => !isActive && !isCompleted;
}
