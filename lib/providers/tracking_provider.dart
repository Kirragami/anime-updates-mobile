import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime_item.dart';
import '../services/tracking_service.dart';
import 'anime_providers.dart';

// Provider for the tracking service
final trackingServiceProvider = Provider((ref) => TrackingService());

// Provider for tracking an individual anime item
final animeTrackingProvider = StateNotifierProvider.family<AnimeTrackingNotifier, bool, AnimeItem>((ref, animeItem) {
  return AnimeTrackingNotifier(animeItem.tracked, animeItem.animeShowId, ref);
});

class AnimeTrackingNotifier extends StateNotifier<bool> {
  final String animeShowId;
  final Ref ref;
  
  AnimeTrackingNotifier(bool isTracked, this.animeShowId, this.ref) : super(isTracked);

  Future<void> toggleTracking() async {
    final trackingService = ref.read(trackingServiceProvider);
    
    // Store the current state for potential rollback
    final previousState = state;
    
    // Immediately update the UI (optimistic update)
    state = !state;
    
    try {
      if (previousState) {
        // Was tracked, now untracking
        final result = await trackingService.untrackAnime(animeShowId);
        if (!result['success']) {
          // Rollback on failure
          state = previousState;
        } else {
          // Successfully untracked - immediately remove from tracked releases list
          ref.read(trackedReleasesNotifierProvider.notifier).removeTrackedItem(animeShowId);
        }
      } else {
        // Was not tracked, now tracking
        final result = await trackingService.trackAnime(animeShowId);
        if (!result['success']) {
          // Rollback on failure
          state = previousState;
        } else {
          // Successfully tracked - refresh the tracked releases list to include new item
          ref.invalidate(trackedReleasesNotifierProvider);
        }
      }
    } catch (e) {
      // Rollback on exception
      state = previousState;
    }
  }

  /// Update the tracking state (useful for syncing with server)
  void updateTrackingState(bool isTracked) {
    state = isTracked;
  }
}