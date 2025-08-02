// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apiServiceHash() => r'73ad3c2e8c0d458c43bdd728c0f0fb75c5c2af98';

/// Provides the API service instance
///
/// Copied from [apiService].
@ProviderFor(apiService)
final apiServiceProvider = AutoDisposeProvider<ApiService>.internal(
  apiService,
  name: r'apiServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$apiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ApiServiceRef = AutoDisposeProviderRef<ApiService>;
String _$downloadServiceHash() => r'75233929b7b2ca846a9ceaee99fbdcdcb43d3dcd';

/// Provides the download service instance
///
/// Copied from [downloadService].
@ProviderFor(downloadService)
final downloadServiceProvider = AutoDisposeProvider<DownloadService>.internal(
  downloadService,
  name: r'downloadServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DownloadServiceRef = AutoDisposeProviderRef<DownloadService>;
String _$imageFetcherServiceHash() =>
    r'48b231850811cca4ea1f3b640214e06d5e248721';

/// Provides the image fetcher service instance
///
/// Copied from [imageFetcherService].
@ProviderFor(imageFetcherService)
final imageFetcherServiceProvider =
    AutoDisposeProvider<ImageFetcherService>.internal(
  imageFetcherService,
  name: r'imageFetcherServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageFetcherServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ImageFetcherServiceRef = AutoDisposeProviderRef<ImageFetcherService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
