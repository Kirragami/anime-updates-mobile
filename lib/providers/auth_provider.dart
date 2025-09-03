import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'anime_providers.dart';

// Authentication state notifier
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  // Initialize authentication state
  Future<void> _initializeAuth() async {
    try {
      await AuthService.restoreSession();
      if (AuthService.isLoggedIn) {
        final user = AuthService.currentUser;
        state = AsyncValue.data(user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await AuthService.login(
        username: username,
        password: password,
      );

      if (kDebugMode) {
        print("Login result");
        print(result);
      }

      if (result['success']) {
        state = AsyncValue.data(AuthService.currentUser);
        // Refresh tracked releases when user logs in
        ref.invalidate(trackedReleasesNotifierProvider);
        return result;
      } else {
        state = const AsyncValue.data(null);
        return result;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'error': error.toString(),
      };
    }
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await AuthService.register(
        username: username,
        password: password,
      );

      // Registration does not log the user in automatically
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'error': error.toString(),
      };
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      final result = await AuthService.logout();
      state = const AsyncValue.data(null);
      // Clear tracked releases when user logs out
      ref.invalidate(trackedReleasesNotifierProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return {
        'success': false,
        'message': 'Logout failed',
        'error': error.toString(),
      };
    }
  }

  // Refresh token
  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final result = await AuthService.refreshAccessToken();
      
      if (result['success']) {
        final user = AuthService.currentUser;
        if (user != null) {
          state = AsyncValue.data(user);
        }
      }
      
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return {
        'success': false,
        'message': 'Token refresh failed',
        'error': error.toString(),
      };
    }
  }

  // Get profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final result = await AuthService.getProfile();
      
      if (result['success']) {
        final user = AuthService.currentUser;
        if (user != null) {
          state = AsyncValue.data(user);
        }
      }
      
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return {
        'success': false,
        'message': 'Failed to get profile',
        'error': error.toString(),
      };
    }
  }

  // Check if user is logged in
  bool get isLoggedIn => AuthService.isLoggedIn;
  
  // Get current user
  User? get currentUser => AuthService.currentUser;
  
  // Get access token
  String? get accessToken => AuthService.accessToken;
}

// Authentication provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
  (ref) => AuthNotifier(ref),
);

// Convenience providers
final authNotifierProvider = Provider<AuthNotifier>((ref) {
  return ref.read(authProvider.notifier);
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
}); 