import 'package:flutter/foundation.dart';
import '../models/anime_item.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/image_fetcher_service.dart';

// Simplified class to track image URLs only
class ImageState extends ChangeNotifier {
  final String animeId;
  String? _imageUrl;

  ImageState(this.animeId);

  String? get imageUrl => _imageUrl;
  bool get hasImage => _imageUrl != null;

  void setImage(String url) {
    _imageUrl = url;
    notifyListeners();
  }

  void reset() {
    _imageUrl = null;
    notifyListeners();
  }
}

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
  
  // New granular image state management
  final Map<String, ImageState> _imageStates = {};

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
  
  // Simplified image getters
  ImageState? getImageState(String animeId) => _imageStates[animeId];
  String? getAnimeImage(String animeId) => _imageStates[animeId]?.imageUrl;
  
  // Helper method to create or get image state with proper listener setup
  ImageState _getOrCreateImageState(String animeId) {
    return _imageStates.putIfAbsent(animeId, () {
      final imageState = ImageState(animeId);
      // Listen to the image state changes and notify our listeners
      imageState.addListener(() {
        notifyListeners();
      });
      return imageState;
    });
  }
  
  // Helper method to check if image loading should be attempted
  bool shouldAttemptImageLoad(String animeId) {
    final imageState = _imageStates[animeId];
    if (imageState == null) return true; // No state exists, should attempt
    
    // Don't attempt if already loaded
    if (imageState.hasImage) return false;
    
    return true;
  }
  
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
      
      // Trigger preloading of initial images in background
      preloadInitialImages();
      
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

  // Load image for a specific anime when it becomes visible
  Future<void> loadImageForAnime(String animeId, String title) async {
    // Get or create image state for this anime with proper listener setup
    final imageState = _getOrCreateImageState(animeId);
    
    // Check if image is already loaded
    if (imageState.hasImage) {
      if (kDebugMode) {
        print('Image load skipped for $title (ID: $animeId) - already loaded: ${imageState.hasImage}');
      }
      return; // Image already loaded
    }
    
    if (kDebugMode) {
      print('Starting image load for $title (ID: $animeId)');
    }
    
    try {
      // Use the improved ImageFetcherService with caching
      final imageUrl = await ImageFetcherService.fetchAnimeImage(title);
      
      if (imageUrl != null) {
        imageState.setImage(imageUrl);
        if (kDebugMode) {
          print('Successfully loaded image for: $title -> $imageUrl');
        }
      } else {
        if (kDebugMode) {
          print('No image found for: $title');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading image for $title: $e');
      }
    }
  }

  // Load images for multiple visible anime items
  Future<void> loadImagesForVisibleItems(List<String> visibleAnimeIds) async {
    // Process images in batches to avoid overwhelming the API
    const batchSize = 3;
    for (int i = 0; i < visibleAnimeIds.length; i += batchSize) {
      final batch = visibleAnimeIds.skip(i).take(batchSize).toList();
      final futures = <Future<void>>[];
      
      for (final animeId in batch) {
        final anime = _animeList.firstWhere((anime) => anime.id == animeId);
        futures.add(loadImageForAnime(animeId, anime.title));
      }
      
      await Future.wait(futures);
      
      // Add a small delay between batches
      if (i + batchSize < visibleAnimeIds.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  // Preload images for the first few items (for better UX)
  Future<void> preloadInitialImages() async {
    if (_animeList.isEmpty) return;
    
    final initialItems = _animeList.take(6).toList(); // Preload first 6 items
    final futures = <Future<void>>[];
    
    for (final anime in initialItems) {
      futures.add(loadImageForAnime(anime.id, anime.title));
    }
    
    // Don't await this - let it run in background
    Future.wait(futures).catchError((e) {
      if (kDebugMode) {
        print('Error preloading initial images: $e');
      }
      return <void>[]; // Return empty list to satisfy the type requirement
    });
  }

  // Clear image cache to free memory
  void clearImageCache() {
    for (final imageState in _imageStates.values) {
      imageState.reset();
    }
    if (kDebugMode) {
      print('Image cache cleared');
    }
  }

  // Get cache statistics
  Map<String, dynamic> getImageCacheStats() {
    return {
      'imageStates': _imageStates.length,
    };
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
    _imageStates.clear();
    _downloadProgress.clear();
    _downloadingItems.clear();
    _downloadedItems.clear();
    _error = null;
    notifyListeners();
  }
}