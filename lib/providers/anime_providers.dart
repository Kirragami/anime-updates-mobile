import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:async';
import '../models/anime_item.dart';
import '../models/anime_show.dart';
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
  String _currentSearchQuery = '';
  bool _isInSearchMode = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get pageSize => _pageSize;
  String get currentSearchQuery => _currentSearchQuery;
  bool get isInSearchMode => _isInSearchMode;

  @override
  Future<List<AnimeItem>> build() async {
    final apiService = ref.read(apiServiceProvider);

    // Reset pagination
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _currentSearchQuery = '';
    _isInSearchMode = false;

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
      Map<String, dynamic> result;
      if (_isInSearchMode && _currentSearchQuery.isNotEmpty) {
        // Load next page of search results
        result = await apiService.searchAnimePage(
          query: _currentSearchQuery,
          page: nextPage,
          size: _pageSize,
        );
      } else {
        // Load next page of normal list
        result = await apiService.fetchAnimePage(page: nextPage, size: _pageSize);
      }

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

  /// Search for anime by title
  Future<void> searchAnime(String query) async {
    // Don't search if query is empty or the same as current query
    if (query.isEmpty) {
      // If query is empty, refresh to show all items
      refresh();
      return;
    }

    if (_currentSearchQuery == query) {
      return;
    }

    _currentSearchQuery = query;
    _isInSearchMode = true;
    _hasMore = true; // We'll paginate via search endpoint
    _currentPage = 0; // reset page so next loadMore fetches page 1
    
    try {
      final apiService = ref.read(apiServiceProvider);
      // Fetch first page of search results
      final result = await apiService.searchAnimePage(
        query: query,
        page: _currentPage,
        size: _pageSize,
      );
      final List<AnimeItem> pageItems = (result['items'] as List<AnimeItem>);
      _hasMore = !(result['last'] as bool);
      _items
        ..clear()
        ..addAll(pageItems);
      state = AsyncData<List<AnimeItem>>(List<AnimeItem>.from(_items));
    } catch (e, st) {
      // Surface error
      state = AsyncError<List<AnimeItem>>(e, st);
    }
  }

  /// Clear search and return to normal browsing mode
  Future<void> clearSearch() async {
    _currentSearchQuery = '';
    _isInSearchMode = false;
    refresh(); // This will reset to normal browsing mode
  }

  /// Update tracking state for all anime items with the same animeShowId
  void updateTrackingForShowId(String animeShowId, bool isTracked) {
    bool hasChanges = false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].animeShowId == animeShowId) {
        _items[i] = _items[i].copyWith(tracked: isTracked);
        hasChanges = true;
      }
    }
    
    if (hasChanges && state.hasValue) {
      state = AsyncData<List<AnimeItem>>(List<AnimeItem>.from(_items));
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
    
    // Add items and remove duplicates based on animeShowId
    _addItemsWithoutDuplicates(pageItems);
    
    // Sync tracking states with the fetched items
    syncTrackingStates();
    
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

      // Add items and remove duplicates based on animeShowId
      _addItemsWithoutDuplicates(pageItems);
      _currentPage = nextPage;
      _hasMore = !last && pageItems.isNotEmpty;

      // Sync tracking states with the new items
      syncTrackingStates();

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

  /// Add items to the list without creating duplicates
  void _addItemsWithoutDuplicates(List<AnimeItem> newItems) {
    for (final item in newItems) {
      // Check if item with same animeShowId already exists
      final existingIndex = _items.indexWhere((existing) => existing.animeShowId == item.animeShowId);
      if (existingIndex == -1) {
        // Item doesn't exist, add it
        _items.add(item);
      } else {
        // Item exists, update it with the latest data
        _items[existingIndex] = item;
      }
    }
  }

  /// Remove an item from the tracked releases list
  void removeTrackedItem(String animeShowId) {
    _items.removeWhere((item) => item.animeShowId == animeShowId);
    // Update the state to reflect the removal
    if (state.hasValue) {
      state = AsyncData<List<AnimeItem>>(List<AnimeItem>.from(_items));
    }
  }

  /// Sync tracking states with the current items
  void syncTrackingStates() {
    // No longer needed since we use anime.tracked directly
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

 
/// Provides the list of tracked shows
@riverpod
class TrackedShowsNotifier extends _$TrackedShowsNotifier {
  // Pagination state
  int _currentPage = 0; // 1-based page index per backend API
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final List<AnimeShow> _items = [];

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get pageSize => _pageSize;

  @override
  Future<List<AnimeShow>> build() async {
    final apiService = ref.read(apiServiceProvider);

    // Reset pagination
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;

    // Fetch first page
    final result = await apiService.fetchTrackedShowsPage(page: _currentPage, size: _pageSize);
    final List<dynamic> rawItems = (result['items'] as List<dynamic>);
    final List<AnimeShow> pageItems = rawItems.map((json) => AnimeShow.fromJson(json)).toList();
    _hasMore = !(result['last'] as bool);
    
    _items.addAll(pageItems);
    return List<AnimeShow>.from(_items);
  }

  /// Refresh the tracked shows list
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
      final result = await apiService.fetchTrackedShowsPage(page: nextPage, size: _pageSize);
      final List<dynamic> rawItems = (result['items'] as List<dynamic>);
      final List<AnimeShow> pageItems = rawItems.map((json) => AnimeShow.fromJson(json)).toList();
      final bool last = result['last'] as bool;

      _items.addAll(pageItems);
      _currentPage = nextPage;
      _hasMore = !last && pageItems.isNotEmpty;

      // Publish new combined list
      state = AsyncData<List<AnimeShow>>(List<AnimeShow>.from(_items));
    } catch (e, st) {
      // Keep previous data, but surface error
      state = AsyncError<List<AnimeShow>>(e, st);
    } finally {
      _isLoadingMore = false;
      ref.read(trackedListLoadingMoreProvider.notifier).setLoading(false);
    }
  }
}