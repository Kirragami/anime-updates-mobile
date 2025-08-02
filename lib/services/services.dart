import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'api_service.dart';
import 'download_service.dart';
import 'image_fetcher_service.dart';

part 'services.g.dart';

/// Provides the API service instance
@riverpod
ApiService apiService(ApiServiceRef ref) => ApiService();

/// Provides the download service instance
@riverpod
DownloadService downloadService(DownloadServiceRef ref) => DownloadService();

/// Provides the image fetcher service instance
@riverpod
ImageFetcherService imageFetcherService(ImageFetcherServiceRef ref) => ImageFetcherService(); 