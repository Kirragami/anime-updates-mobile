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
  String _currentSearchQuery = '';

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get pageSize => _pageSize;
  String get currentSearchQuery => _currentSearchQuery;

  @override
  Future<List<AnimeItem>> build() async {
    final apiService = ref.read(apiServiceProvider);

    // Reset pagination
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _currentSearchQuery = '';

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
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final searchResults = await apiService.searchAnime(query);
      
      // Update state with search results
      state = AsyncData<List<AnimeItem>>(searchResults);
    } catch (e, st) {
      // Surface error
      state = AsyncError<List<AnimeItem>>(e, st);
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

 