import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/anime_item.dart';
import '../services/services.dart';
import '../services/image_fetcher_service.dart';

part 'anime_providers.g.dart';

/// Provides the list of anime items
@riverpod
class AnimeListNotifier extends _$AnimeListNotifier {
  @override
  Future<List<AnimeItem>> build() async {
    final apiService = ref.read(apiServiceProvider);
    return apiService.fetchAnimeList();
  }

  /// Refresh the anime list
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provides the image URL for a specific anime
@riverpod
Future<String?> animeImage(AnimeImageRef ref, String animeId, String title) async {
  return ImageFetcherService.fetchAnimeImage(title);
}

/// Provides initial image loading for the first few items
@riverpod
Future<void> preloadInitialImages(PreloadInitialImagesRef ref) async {
  final animeList = ref.watch(animeListNotifierProvider);
  
  await animeList.when(
    data: (animeList) async {
      final initialItems = animeList.take(6).toList();
      final futures = <Future<void>>[];
      
      for (final anime in initialItems) {
        futures.add(ref.read(animeImageProvider(anime.id, anime.title).future));
      }
      
      await Future.wait(futures);
    },
    loading: () async {},
    error: (_, __) async {},
  );
}

/// Provides download progress for a specific anime
@riverpod
class DownloadProgressNotifier extends _$DownloadProgressNotifier {
  @override
  Map<String, double> build() => {};

  void setProgress(String animeId, double progress) {
    state = {...state, animeId: progress};
  }

  void removeProgress(String animeId) {
    final newState = Map<String, double>.from(state);
    newState.remove(animeId);
    state = newState;
  }

  double getProgress(String animeId) => state[animeId] ?? 0.0;
}

/// Provides download states for anime items
@riverpod
class DownloadStatesNotifier extends _$DownloadStatesNotifier {
  @override
  Map<String, bool> build() => {};

  void setDownloading(String animeId, bool isDownloading) {
    state = {...state, animeId: isDownloading};
  }

  void setDownloaded(String animeId, bool isDownloaded) {
    state = {...state, animeId: isDownloaded};
  }

  bool isDownloading(String animeId) => state[animeId] ?? false;
  bool isDownloaded(String animeId) => state[animeId] ?? false;
}

/// Provides the number of active downloads
@riverpod
int activeDownloadCount(ActiveDownloadCountRef ref) {
  final downloadStates = ref.watch(downloadStatesNotifierProvider);
  return downloadStates.values.where((isDownloading) => isDownloading).length;
}

/// Provides whether there are any active downloads
@riverpod
bool hasActiveDownloads(HasActiveDownloadsRef ref) {
  return ref.watch(activeDownloadCountProvider) > 0;
}

/// Provides the number of downloaded items
@riverpod
int downloadedCount(DownloadedCountRef ref) {
  final downloadStates = ref.watch(downloadStatesNotifierProvider);
  return downloadStates.values.where((isDownloaded) => isDownloaded).length;
}

/// Provides download operations for anime items
@riverpod
class DownloadOperationsNotifier extends _$DownloadOperationsNotifier {
  @override
  Future<void> build() async {
    // Check existing downloads when the provider is first created
    final animeList = ref.watch(animeListNotifierProvider);
    await animeList.when(
      data: (animeList) => checkExistingDownloads(animeList),
      loading: () async {},
      error: (_, __) async {},
    );
  }

  /// Download an anime item
  Future<void> downloadAnime(AnimeItem anime) async {
    final downloadService = ref.read(downloadServiceProvider);
    final progressNotifier = ref.read(downloadProgressNotifierProvider.notifier);
    final statesNotifier = ref.read(downloadStatesNotifierProvider.notifier);

    // Check if already downloading or downloaded
    if (statesNotifier.isDownloading(anime.id) || statesNotifier.isDownloaded(anime.id)) {
      if (kDebugMode) {
        print('Item ${anime.id} is already downloading or downloaded, skipping...');
      }
      return;
    }

    // Set as downloading
    statesNotifier.setDownloading(anime.id, true);
    progressNotifier.setProgress(anime.id, 0.0);

    if (kDebugMode) {
      print('Starting download for: ${anime.title} (ID: ${anime.id})');
    }

    try {
      final filename = '${anime.title.replaceAll(" ", "_")}.torrent';
      
      await downloadService.downloadFile(
        url: anime.downloadUrl,
        filename: filename,
        onProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            progressNotifier.setProgress(anime.id, progress);
            if (kDebugMode) {
              print('Progress for ${anime.id}: ${(progress * 100).toStringAsFixed(1)}%');
            }
          }
        },
      );

      // Download completed
      progressNotifier.setProgress(anime.id, 1.0);
      statesNotifier.setDownloaded(anime.id, true);
      statesNotifier.setDownloading(anime.id, false);

      if (kDebugMode) {
        print('Download completed for ${anime.id}');
      }

      // Reset progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        progressNotifier.removeProgress(anime.id);
      });

    } catch (e) {
      // Reset on error
      statesNotifier.setDownloading(anime.id, false);
      progressNotifier.removeProgress(anime.id);
      if (kDebugMode) {
        print('Download error for ${anime.id}: $e');
      }
      rethrow;
    }
  }

  /// Delete a downloaded anime
  Future<void> deleteDownload(AnimeItem anime) async {
    final downloadService = ref.read(downloadServiceProvider);
    final statesNotifier = ref.read(downloadStatesNotifierProvider.notifier);

    try {
      await downloadService.deleteFile(anime.title);
      statesNotifier.setDownloaded(anime.id, false);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting download for ${anime.id}: $e');
      }
      rethrow;
    }
  }

  /// Open a downloaded anime file
  Future<bool> openDownloadedFile(AnimeItem anime) async {
    final downloadService = ref.read(downloadServiceProvider);

    try {
      return await downloadService.openFile(anime.title);
    } catch (e) {
      if (kDebugMode) {
        print('Error opening file for ${anime.id}: $e');
      }
      return false;
    }
  }

  /// Check existing downloads
  Future<void> checkExistingDownloads(List<AnimeItem> animeList) async {
    final downloadService = ref.read(downloadServiceProvider);
    final statesNotifier = ref.read(downloadStatesNotifierProvider.notifier);

    try {
      for (final anime in animeList) {
        final exists = await downloadService.checkFileExists(anime.title);
        statesNotifier.setDownloaded(anime.id, exists);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking existing downloads: $e');
      }
    }
  }
} 