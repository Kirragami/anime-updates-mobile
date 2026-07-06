import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'anime_providers.dart';
import 'friends_providers.dart';

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

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


      if (result['success']) {
        state = AsyncValue.data(AuthService.currentUser);
        ref.invalidate(trackedReleasesNotifierProvider);
        ref.invalidate(tomodachiNotifierProvider);
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

  Future<Map<String, dynamic>> logout() async {
    try {
      final result = await AuthService.logout();
      state = const AsyncValue.data(null);
      ref.invalidate(trackedReleasesNotifierProvider);
      ref.invalidate(tomodachiNotifierProvider);
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

  bool get isLoggedIn => AuthService.isLoggedIn;
  
  User? get currentUser => AuthService.currentUser;
  
  String? get accessToken => AuthService.accessToken;
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
  (ref) => AuthNotifier(ref),
);

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