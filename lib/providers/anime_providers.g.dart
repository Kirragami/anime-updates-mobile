// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$animeImageHash() => r'9a12f4ed7ced3080cc9a99ce7361727869081932';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provides the image URL for a specific anime
///
/// Copied from [animeImage].
@ProviderFor(animeImage)
const animeImageProvider = AnimeImageFamily();

/// Provides the image URL for a specific anime
///
/// Copied from [animeImage].
class AnimeImageFamily extends Family<AsyncValue<String?>> {
  /// Provides the image URL for a specific anime
  ///
  /// Copied from [animeImage].
  const AnimeImageFamily();

  /// Provides the image URL for a specific anime
  ///
  /// Copied from [animeImage].
  AnimeImageProvider call(
    String animeId,
    String title,
  ) {
    return AnimeImageProvider(
      animeId,
      title,
    );
  }

  @override
  AnimeImageProvider getProviderOverride(
    covariant AnimeImageProvider provider,
  ) {
    return call(
      provider.animeId,
      provider.title,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'animeImageProvider';
}

/// Provides the image URL for a specific anime
///
/// Copied from [animeImage].
class AnimeImageProvider extends AutoDisposeFutureProvider<String?> {
  /// Provides the image URL for a specific anime
  ///
  /// Copied from [animeImage].
  AnimeImageProvider(
    String animeId,
    String title,
  ) : this._internal(
          (ref) => animeImage(
            ref as AnimeImageRef,
            animeId,
            title,
          ),
          from: animeImageProvider,
          name: r'animeImageProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$animeImageHash,
          dependencies: AnimeImageFamily._dependencies,
          allTransitiveDependencies:
              AnimeImageFamily._allTransitiveDependencies,
          animeId: animeId,
          title: title,
        );

  AnimeImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.animeId,
    required this.title,
  }) : super.internal();

  final String animeId;
  final String title;

  @override
  Override overrideWith(
    FutureOr<String?> Function(AnimeImageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AnimeImageProvider._internal(
        (ref) => create(ref as AnimeImageRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        animeId: animeId,
        title: title,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _AnimeImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AnimeImageProvider &&
        other.animeId == animeId &&
        other.title == title;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, animeId.hashCode);
    hash = _SystemHash.combine(hash, title.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AnimeImageRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `animeId` of this provider.
  String get animeId;

  /// The parameter `title` of this provider.
  String get title;
}

class _AnimeImageProviderElement
    extends AutoDisposeFutureProviderElement<String?> with AnimeImageRef {
  _AnimeImageProviderElement(super.provider);

  @override
  String get animeId => (origin as AnimeImageProvider).animeId;
  @override
  String get title => (origin as AnimeImageProvider).title;
}

String _$preloadInitialImagesHash() =>
    r'ce9f764019adb1c9fb7d2aea745f5c0fb9fa6aa9';

/// Provides initial image loading for the first few items
///
/// Copied from [preloadInitialImages].
@ProviderFor(preloadInitialImages)
final preloadInitialImagesProvider = AutoDisposeFutureProvider<void>.internal(
  preloadInitialImages,
  name: r'preloadInitialImagesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preloadInitialImagesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PreloadInitialImagesRef = AutoDisposeFutureProviderRef<void>;
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
String _$animeListNotifierHash() => r'9d120cd698c5a99174b43aafddbd21dda6389ff7';

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
    r'7a814ad08cabd0ff46813da84c8d5b24cc74f700';

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
