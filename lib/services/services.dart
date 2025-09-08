import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'download_service.dart';
import 'speed_limit_service.dart';

part 'services.g.dart';

/// Provides the API service instance
@riverpod
ApiService apiService(ApiServiceRef ref) => ApiService();

/// Provides the download service instance
@riverpod
DownloadService downloadService(DownloadServiceRef ref) => DownloadService();

/// Provides the auth service instance
@riverpod
AuthService authService(AuthServiceRef ref) => AuthService();

/// Provides the speed limit service instance
@riverpod
SpeedLimitService speedLimitService(SpeedLimitServiceRef ref) => SpeedLimitService(); 