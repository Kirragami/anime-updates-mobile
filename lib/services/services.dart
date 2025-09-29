import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'download_service.dart';
import 'speed_limit_service.dart';
import 'update_service.dart';

part 'services.g.dart';

@riverpod
ApiService apiService(ApiServiceRef ref) => ApiService();

@riverpod
DownloadService downloadService(DownloadServiceRef ref) => DownloadService();

@riverpod
AuthService authService(AuthServiceRef ref) => AuthService();

@riverpod
SpeedLimitService speedLimitService(SpeedLimitServiceRef ref) => SpeedLimitService();

@riverpod
UpdateService updateService(UpdateServiceRef ref) => UpdateService(); 