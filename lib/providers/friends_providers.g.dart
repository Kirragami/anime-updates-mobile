// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingTomodachiRequestsCountHash() =>
    r'80e328b4ca9749fac1a4e4d8ca3e452fc605d3b0';

/// See also [pendingTomodachiRequestsCount].
@ProviderFor(pendingTomodachiRequestsCount)
final pendingTomodachiRequestsCountProvider = AutoDisposeProvider<int>.internal(
  pendingTomodachiRequestsCount,
  name: r'pendingTomodachiRequestsCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingTomodachiRequestsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PendingTomodachiRequestsCountRef = AutoDisposeProviderRef<int>;
String _$tomodachiNotifierHash() => r'8c6adc3d18ba7d16e1a4e5dffb49c60c2fb67157';

/// See also [TomodachiNotifier].
@ProviderFor(TomodachiNotifier)
final tomodachiNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TomodachiNotifier, List<Tomodachi>>.internal(
  TomodachiNotifier.new,
  name: r'tomodachiNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tomodachiNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TomodachiNotifier = AutoDisposeAsyncNotifier<List<Tomodachi>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
