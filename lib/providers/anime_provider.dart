import 'package:flutter/foundation.dart';
import '../models/anime_item.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class AnimeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DownloadService _downloadService = DownloadService();

  List<AnimeItem> _animeList = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  Map<String, double> _downloadProgress = {};
  Map<String, bool> _downloadingItems = {};
  Map<String, bool> _downloadedItems = {};
  


  // Getters
  List<AnimeItem> get animeList => _animeList;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _animeList.isEmpty && !_isLoading;

  double getDownloadProgress(String itemId) => _downloadProgress[itemId] ?? 0.0;
  bool isDownloading(String itemId) => _downloadingItems[itemId] ?? false;
  bool isDownloaded(String itemId) => _downloadedItems[itemId] ?? false;
  

  
  // Map getters for grid view
  Map<String, double> get downloadProgress => _downloadProgress;
  Map<String, bool> get downloadingItems => _downloadingItems;
  Map<String, bool> get downloadedItems => _downloadedItems;

  // Methods
  Future<void> fetchAnimeList({bool isRefresh = false}) async {
    if (isRefresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final animeList = await _apiService.fetchAnimeList();
      _animeList = animeList;
      _error = null;
      
      // Check for existing downloads after fetching the list
      await _checkExistingDownloads();
      
      // Don't load images here - they will be loaded lazily when visible
      // This ensures the list shows up immediately after API call
      
      if (kDebugMode) {
        print('Fetched ${animeList.length} anime items');
        for (var anime in animeList) {
          print('Anime: ${anime.title} (ID: ${anime.id})');
        }
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error fetching anime list: $e');
      }
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _checkExistingDownloads() async {
    try {
      for (final anime in _animeList) {
        final exists = await _downloadService.checkFileExists(anime.title);
        _downloadedItems[anime.id] = exists;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking existing downloads: $e');
      }
    }
  }











  Future<void> downloadAnime(AnimeItem anime) async {
    if (kDebugMode) {
      print('Starting download for: ${anime.title} (ID: ${anime.id})');
      print('Current downloading items: $_downloadingItems');
    }

    // Check if this specific item is already downloading
    if (_downloadingItems[anime.id] == true) {
      if (kDebugMode) {
        print('Item ${anime.id} is already downloading, skipping...');
      }
      return;
    }

    // Check if already downloaded
    if (_downloadedItems[anime.id] == true) {
      if (kDebugMode) {
        print('Item ${anime.id} is already downloaded, skipping...');
      }
      return;
    }

    // Set this specific item as downloading
    _downloadingItems[anime.id] = true;
    _downloadProgress[anime.id] = 0.0;
    
    if (kDebugMode) {
      print('Set ${anime.id} as downloading. Current state: $_downloadingItems');
    }
    
    notifyListeners();

    try {
      final filename = '${anime.title.replaceAll(" ", "_")}.torrent';
      
      await _downloadService.downloadFile(
        url: anime.downloadUrl,
        filename: filename,
        onProgress: (received, total) {
          if (total != -1) {
            // Update progress for this specific item only
            _downloadProgress[anime.id] = received / total;
            if (kDebugMode) {
              print('Progress for ${anime.id}: ${(received / total * 100).toStringAsFixed(1)}%');
            }
            notifyListeners();
          }
        },
      );

      // Download completed for this specific item
      _downloadProgress[anime.id] = 1.0;
      _downloadedItems[anime.id] = true;
      if (kDebugMode) {
        print('Download completed for ${anime.id}');
      }
      notifyListeners();
      
      // Reset this specific item after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        _downloadProgress.remove(anime.id);
        _downloadingItems[anime.id] = false;
        if (kDebugMode) {
          print('Reset download state for ${anime.id}');
        }
        notifyListeners();
      });

    } catch (e) {
      _error = e.toString();
      // Reset only this specific item on error
      _downloadingItems[anime.id] = false;
      _downloadProgress.remove(anime.id);
      if (kDebugMode) {
        print('Download error for ${anime.id}: $e');
      }
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearDownloadProgress(String itemId) {
    _downloadProgress.remove(itemId);
    _downloadingItems[itemId] = false;
    notifyListeners();
  }

  Future<void> deleteDownload(AnimeItem anime) async {
    try {
      await _downloadService.deleteFile(anime.title);
      _downloadedItems[anime.id] = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting download for ${anime.id}: $e');
      }
    }
  }

  Future<bool> openDownloadedFile(AnimeItem anime) async {
    try {
      final success = await _downloadService.openFile(anime.title);
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening file for ${anime.id}: $e');
      }
      return false;
    }
  }

  Future<void> refreshDownloadStates() async {
    await _checkExistingDownloads();
  }

  bool hasActiveDownloads() {
    return _downloadingItems.values.any((isDownloading) => isDownloading);
  }

  // Get the number of active downloads
  int get activeDownloadCount {
    return _downloadingItems.values.where((isDownloading) => isDownloading).length;
  }

  // Get the number of downloaded items
  int get downloadedCount {
    return _downloadedItems.values.where((isDownloaded) => isDownloaded).length;
  }

  // Clear all data (useful for refresh)
  void clearAllData() {
    _animeList.clear();
    _downloadProgress.clear();
    _downloadingItems.clear();
    _downloadedItems.clear();
    _error = null;
    notifyListeners();
  }
}