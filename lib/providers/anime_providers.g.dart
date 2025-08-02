// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$animeImageHash() => r'4b061014023d746b4e5ebff2cb33571510fcbc54';

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
    r'3c1b951c81729b9de2c457f2f4a78b79c94cadea';

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
String _$downloadedCountHash() => r'5669ddf8029cbf2111598f9d373d2d7a1b664c5d';

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
String _$animeListNotifierHash() => r'ee7002c1cfd3063e08dea4f060947f3160b4661b';

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
    r'1bd3b7ae557d086aaf332b2fd4040a1af0297377';

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
    r'8f1a89cb3e9f07ed8e8933936a0d8f0149161567';

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
