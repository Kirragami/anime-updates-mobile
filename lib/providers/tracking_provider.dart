import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime_item.dart';
import '../services/tracking_service.dart';

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
        }
      } else {
        // Was not tracked, now tracking
        final result = await trackingService.trackAnime(animeShowId);
        if (!result['success']) {
          // Rollback on failure
          state = previousState;
        }
      }
    } catch (e) {
      // Rollback on exception
      state = previousState;
    }
  }
}