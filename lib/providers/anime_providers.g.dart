// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeDownloadCountHash() =>
    r'69cc3df0ea8a00efaeb358444de63acf2942c3de';

/// Provides the number of active downloads
///
/// Copied from [activeDownloadCount].
@ProviderFor(activeDownloadCount)
final activeDownloadCountProvider = AutoDisposeProvider<int>.internal(
  activeDownloadCount,
  name: r'activeDownloadCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeDownloadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ActiveDownloadCountRef = AutoDisposeProviderRef<int>;
String _$hasActiveDownloadsHash() =>
    r'effd60adef1b86d096f121f5211147c1b6391e41';

/// Provides whether there are any active downloads
///
/// Copied from [hasActiveDownloads].
@ProviderFor(hasActiveDownloads)
final hasActiveDownloadsProvider = AutoDisposeProvider<bool>.internal(
  hasActiveDownloads,
  name: r'hasActiveDownloadsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasActiveDownloadsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HasActiveDownloadsRef = AutoDisposeProviderRef<bool>;
String _$downloadedCountHash() => r'df8749c8df6639ad0f10c26e2ab9acdb9e848f23';

/// Provides the number of downloaded items
///
/// Copied from [downloadedCount].
@ProviderFor(downloadedCount)
final downloadedCountProvider = AutoDisposeProvider<int>.internal(
  downloadedCount,
  name: r'downloadedCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadedCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DownloadedCountRef = AutoDisposeProviderRef<int>;
String _$animeListNotifierHash() => r'045f2be4b73bdb13dbbebce45dcdd835e2ed05e3';

/// Provides the list of anime items
///
/// Copied from [AnimeListNotifier].
@ProviderFor(AnimeListNotifier)
final animeListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    AnimeListNotifier, List<AnimeItem>>.internal(
  AnimeListNotifier.new,
  name: r'animeListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$animeListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AnimeListNotifier = AutoDisposeAsyncNotifier<List<AnimeItem>>;
String _$trackedReleasesNotifierHash() =>
    r'fe55207a4d3d937a472bab5e480eabec3ee0d4a1';

/// Provides the list of tracked releases (authenticated)
///
/// Copied from [TrackedReleasesNotifier].
@ProviderFor(TrackedReleasesNotifier)
final trackedReleasesNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TrackedReleasesNotifier, List<AnimeItem>>.internal(
  TrackedReleasesNotifier.new,
  name: r'trackedReleasesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trackedReleasesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TrackedReleasesNotifier = AutoDisposeAsyncNotifier<List<AnimeItem>>;
String _$trackedListLoadingMoreHash() =>
    r'a195d00d59509815f2a52b82db5fb9ba2bbdd378';

/// Exposes whether the tracked releases list is currently loading the next page
///
/// Copied from [TrackedListLoadingMore].
@ProviderFor(TrackedListLoadingMore)
final trackedListLoadingMoreProvider =
    AutoDisposeNotifierProvider<TrackedListLoadingMore, bool>.internal(
  TrackedListLoadingMore.new,
  name: r'trackedListLoadingMoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trackedListLoadingMoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TrackedListLoadingMore = AutoDisposeNotifier<bool>;
String _$listLoadingMoreHash() => r'b5003a7fc198dec746598fa597f691186a07cf77';

/// Exposes whether the list is currently loading the next page (for UI skeletons)
///
/// Copied from [ListLoadingMore].
@ProviderFor(ListLoadingMore)
final listLoadingMoreProvider =
    AutoDisposeNotifierProvider<ListLoadingMore, bool>.internal(
  ListLoadingMore.new,
  name: r'listLoadingMoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$listLoadingMoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ListLoadingMore = AutoDisposeNotifier<bool>;
String _$downloadProgressNotifierHash() =>
    r'dd5a40a3e0ae8b33cbc78aba7a76365ee487837d';

/// Provides download progress for a specific anime
///
/// Copied from [DownloadProgressNotifier].
@ProviderFor(DownloadProgressNotifier)
final downloadProgressNotifierProvider = AutoDisposeNotifierProvider<
    DownloadProgressNotifier, Map<String, double>>.internal(
  DownloadProgressNotifier.new,
  name: r'downloadProgressNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadProgressNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DownloadProgressNotifier = AutoDisposeNotifier<Map<String, double>>;
String _$downloadStatesNotifierHash() =>
    r'8f07fe97a351ab30c08619c9f7c4be781d7e86b2';

/// Provides download states for anime items
///
/// Copied from [DownloadStatesNotifier].
@ProviderFor(DownloadStatesNotifier)
final downloadStatesNotifierProvider = AutoDisposeNotifierProvider<
    DownloadStatesNotifier, Map<String, bool>>.internal(
  DownloadStatesNotifier.new,
  name: r'downloadStatesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadStatesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DownloadStatesNotifier = AutoDisposeNotifier<Map<String, bool>>;
String _$downloadOperationsNotifierHash() =>
    r'1fb047f56bf0ad7e7b5be482067a7a226642edef';

/// Provides download operations for anime items
///
/// Copied from [DownloadOperationsNotifier].
@ProviderFor(DownloadOperationsNotifier)
final downloadOperationsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<DownloadOperationsNotifier, void>.internal(
  DownloadOperationsNotifier.new,
  name: r'downloadOperationsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadOperationsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DownloadOperationsNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
