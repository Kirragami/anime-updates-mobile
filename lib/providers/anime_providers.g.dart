
part of 'anime_providers.dart';


String _$animeListNotifierHash() => r'b4a0090e2c4daf9086933e857b234964dbeadb92';

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
    r'd49aca223680cf556fadef5080e623f3e8af5b2f';

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
