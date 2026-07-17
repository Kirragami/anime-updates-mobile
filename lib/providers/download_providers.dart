import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_download.dart';
import '../models/completed_download.dart';
import '../services/active_downloads_manager.dart';
import '../services/auth_service.dart';
import '../services/completed_downloads_manager.dart';
import '../services/services.dart';
import 'anime_providers.dart';

final activeDownloadsProvider =
    StateNotifierProvider<ActiveDownloadsNotifier, Map<String, ActiveDownload>>(
        (ref) {
  return ActiveDownloadsNotifier(ref);
});

class ActiveDownloadsNotifier
    extends StateNotifier<Map<String, ActiveDownload>> {
  ActiveDownloadsNotifier(this.ref) : super({}) {
    _manager.stateNotifier.addListener(_onStateChanged);
    state = _manager.activeDownloads;
  }

  final Ref ref;
  final ActiveDownloadsManager _manager = ActiveDownloadsManager();

  void _onStateChanged() {
    state = _manager.activeDownloads;
  }

  Future<void> startDownload({
    required String releaseId,
    required String magnetUrl,
    required String fileName,
    required String showName,
    required String episode,
    String? animeShowId,
    String? imageUrl,
    bool isTracked = false,
  }) async {
    final showId = animeShowId?.trim() ?? '';
    final shouldTrack =
        ref.read(userPreferencesServiceProvider).autoTrackOnDownload &&
            AuthService.isLoggedIn &&
            !isTracked &&
            showId.isNotEmpty;
    if (shouldTrack) {
      ref
          .read(animeListNotifierProvider.notifier)
          .updateTrackingForShowId(showId, true);
    }

    await _manager.startDownload(
      releaseId: releaseId,
      magnetUrl: magnetUrl,
      fileName: fileName,
      showName: showName,
      episode: episode,
      animeShowId: animeShowId,
      imageUrl: imageUrl,
      isTracked: isTracked,
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

final completedDownloadsProvider = StateNotifierProvider<
    CompletedDownloadsNotifier, Map<String, CompletedDownload>>((ref) {
  return CompletedDownloadsNotifier();
});

class CompletedDownloadsNotifier
    extends StateNotifier<Map<String, CompletedDownload>> {
  final CompletedDownloadsManager _manager = CompletedDownloadsManager();

  CompletedDownloadsNotifier() : super({}) {
    _manager.stateNotifier.addListener(_onStateChanged);
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

  Future<void> deleteAllDownloadsForShow(String showId) async {
    await _manager.deleteAllDownloadsForShow(showId);
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

  Future<String?> getAnimeImagePath(String animeShowId) async {
    return await _manager.getAnimeImagePath(animeShowId);
  }

  Map<String, List<CompletedDownload>> getDownloadsGroupedByShowId() {
    return _manager.getDownloadsGroupedByShowId();
  }

  @override
  void dispose() {
    _manager.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }
}

final downloadStatusProvider =
    Provider.family<DownloadStatus, String>((ref, releaseId) {
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
      status: ActiveDownloadStatus.downloading,
      speed: 0,
    );
  } else {
    return DownloadStatus(
      isActive: false,
      isCompleted: false,
      progress: 0.0,
      status: ActiveDownloadStatus.downloading,
      speed: 0,
    );
  }
});

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

  bool get isDownloading =>
      isActive && status == ActiveDownloadStatus.downloading;
  bool get isPaused => isActive && status == ActiveDownloadStatus.paused;
  bool get isNotDownloaded => !isActive && !isCompleted;
}
