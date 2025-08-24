import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:async';
import '../models/anime_item.dart';
import '../services/services.dart';


part 'anime_providers.g.dart';



/// Provides the list of anime items
@riverpod
class AnimeListNotifier extends _$AnimeListNotifier {
  // Pagination state
  int _currentPage = 0; // 1-based page index per backend API
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final List<AnimeItem> _items = [];

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get pageSize => _pageSize;

  @override
  Future<List<AnimeItem>> build() async {
    final apiService = ref.read(apiServiceProvider);

    // Reset pagination
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;

    // Fetch first page
    final result = await apiService.fetchAnimePage(page: _currentPage, size: _pageSize);
    final List<AnimeItem> pageItems = (result['items'] as List<AnimeItem>);
    _hasMore = !(result['last'] as bool);
    _items.addAll(pageItems);
    return List<AnimeItem>.from(_items);
  }

  /// Refresh the anime list
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Load next page and append to current state
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    // Notify UI we started loading more
    ref.read(listLoadingMoreProvider.notifier).setLoading(true);
    _isLoadingMore = true;
    final apiService = ref.read(apiServiceProvider);
    final nextPage = _currentPage + 1;

    try {
      final result = await apiService.fetchAnimePage(page: nextPage, size: _pageSize);
      final List<AnimeItem> pageItems = (result['items'] as List<AnimeItem>);
      final bool last = result['last'] as bool;

      _items.addAll(pageItems);
      _currentPage = nextPage;
      _hasMore = !last && pageItems.isNotEmpty;

      // Publish new combined list
      state = AsyncData<List<AnimeItem>>(List<AnimeItem>.from(_items));
    } catch (e, st) {
      // Keep previous data, but surface error
      state = AsyncError<List<AnimeItem>>(e, st);
    } finally {
      _isLoadingMore = false;
      ref.read(listLoadingMoreProvider.notifier).setLoading(false);
    }
  }
}

/// Provides the list of tracked releases (authenticated)
@riverpod
class TrackedReleasesNotifier extends _$TrackedReleasesNotifier {
  // Pagination state
  int _currentPage = 0; // 1-based page index per backend API
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final List<AnimeItem> _items = [];

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get pageSize => _pageSize;

  @override
  Future<List<AnimeItem>> build() async {
    final apiService = ref.read(apiServiceProvider);

    // Reset pagination
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;

    // Fetch first page
    final result = await apiService.fetchTrackedReleasesPage(page: _currentPage, size: _pageSize);
    final List<AnimeItem> pageItems = (result['items'] as List<AnimeItem>);
    _hasMore = !(result['last'] as bool);
    _items.addAll(pageItems);
    return List<AnimeItem>.from(_items);
  }

  /// Refresh the tracked releases list
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Load next page and append to current state
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    // Notify UI we started loading more
    ref.read(trackedListLoadingMoreProvider.notifier).setLoading(true);
    _isLoadingMore = true;
    final apiService = ref.read(apiServiceProvider);
    final nextPage = _currentPage + 1;

    try {
      final result = await apiService.fetchTrackedReleasesPage(page: nextPage, size: _pageSize);
      final List<AnimeItem> pageItems = (result['items'] as List<AnimeItem>);
      final bool last = result['last'] as bool;

      _items.addAll(pageItems);
      _currentPage = nextPage;
      _hasMore = !last && pageItems.isNotEmpty;

      // Publish new combined list
      state = AsyncData<List<AnimeItem>>(List<AnimeItem>.from(_items));
    } catch (e, st) {
      // Keep previous data, but surface error
      state = AsyncError<List<AnimeItem>>(e, st);
    } finally {
      _isLoadingMore = false;
      ref.read(trackedListLoadingMoreProvider.notifier).setLoading(false);
    }
  }
}

/// Exposes whether the tracked releases list is currently loading the next page
@riverpod
class TrackedListLoadingMore extends _$TrackedListLoadingMore {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
}

/// Exposes whether the list is currently loading the next page (for UI skeletons)
@riverpod
class ListLoadingMore extends _$ListLoadingMore {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
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
    state = {...state, 'downloading_$animeId': isDownloading};
  }

  void setDownloaded(String animeId, bool isDownloaded) {
    state = {...state, 'downloaded_$animeId': isDownloaded};
  }

  bool isDownloading(String animeId) => state['downloading_$animeId'] ?? false;
  bool isDownloaded(String animeId) => state['downloaded_$animeId'] ?? false;
}

/// Provides the number of active downloads
@riverpod
int activeDownloadCount(ActiveDownloadCountRef ref) {
  final downloadStates = ref.watch(downloadStatesNotifierProvider);
  final notifier = ref.read(downloadStatesNotifierProvider.notifier);
  
  // Count all anime items that are currently downloading
  final animeList = ref.watch(animeListNotifierProvider);
  return animeList.when(
    data: (animeList) => animeList.where((anime) => notifier.isDownloading(anime.id)).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
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
  final notifier = ref.read(downloadStatesNotifierProvider.notifier);
  
  // Count all anime items that are downloaded
  final animeList = ref.watch(animeListNotifierProvider);
  return animeList.when(
    data: (animeList) => animeList.where((anime) => notifier.isDownloaded(anime.id)).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
}

/// Provides download operations for anime items
@riverpod
class DownloadOperationsNotifier extends _$DownloadOperationsNotifier {
  @override
  Future<void> build() async {
    if (kDebugMode) {
      print('DownloadOperationsNotifier: Initializing...');
    }
    
    // Check existing downloads for both regular anime list and tracked releases
    final animeList = ref.watch(animeListNotifierProvider);
    final trackedReleases = ref.watch(trackedReleasesNotifierProvider);
    
    // Check regular anime list
    await animeList.when(
      data: (animeList) async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Checking existing downloads for ${animeList.length} anime items');
        }
        await checkExistingDownloads(animeList);
      },
      loading: () async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Anime list is loading');
        }
      },
      error: (_, __) async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Anime list has error');
        }
      },
    );
    
    // Check tracked releases
    await trackedReleases.when(
      data: (trackedList) async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Checking existing downloads for ${trackedList.length} tracked items');
        }
        await checkExistingDownloads(trackedList);
      },
      loading: () async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Tracked releases list is loading');
        }
      },
      error: (_, __) async {
        if (kDebugMode) {
          print('DownloadOperationsNotifier: Tracked releases list has error');
        }
      },
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
      print('Downloading state set to: ${statesNotifier.isDownloading(anime.id)}');
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
        print('Downloaded state: ${statesNotifier.isDownloaded(anime.id)}');
        print('Downloading state: ${statesNotifier.isDownloading(anime.id)}');
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

    if (kDebugMode) {
      print('Deleting download for: ${anime.title} (ID: ${anime.id})');
      print('Current downloaded state: ${statesNotifier.isDownloaded(anime.id)}');
    }

    try {
      await downloadService.deleteFile(anime.title);
      statesNotifier.setDownloaded(anime.id, false);
      
      if (kDebugMode) {
        print('Delete completed for: ${anime.title} (ID: ${anime.id})');
        print('New downloaded state: ${statesNotifier.isDownloaded(anime.id)}');
      }
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

    if (kDebugMode) {
      print('Checking existing downloads for ${animeList.length} items');
    }

    try {
      for (final anime in animeList) {
        final exists = await downloadService.checkFileExists(anime.title);
        statesNotifier.setDownloaded(anime.id, exists);
        
        if (kDebugMode) {
          print('File exists for ${anime.title}: $exists');
        }
      }
      
      if (kDebugMode) {
        print('Finished checking existing downloads');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking existing downloads: $e');
      }
    }
  }
  
  /// Recheck existing downloads for tracked releases
  Future<void> recheckTrackedDownloads() async {
    if (kDebugMode) {
      print('Rechecking existing downloads for tracked releases');
    }
    
    final trackedReleases = ref.watch(trackedReleasesNotifierProvider);
    await trackedReleases.when(
      data: (trackedList) async {
        if (kDebugMode) {
          print('Rechecking existing downloads for ${trackedList.length} tracked items');
        }
        await checkExistingDownloads(trackedList);
      },
      loading: () async {
        if (kDebugMode) {
          print('Tracked releases list is loading, cannot recheck');
        }
      },
      error: (_, __) async {
        if (kDebugMode) {
          print('Tracked releases list has error, cannot recheck');
        }
      },
    );
  }
}

 