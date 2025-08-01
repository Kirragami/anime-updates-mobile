class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://anime-updates-api.kirragami.com';
  static const String animeEndpoint = '/api/anime/downloads';
  static const String fullApiUrl = '$baseUrl$animeEndpoint';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // App Configuration
  static const String appName = 'Anime Updates';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String downloadHistoryKey = 'download_history';
  static const String userPreferencesKey = 'user_preferences';
  
  // Error Messages
  static const String networkError = 'Network connection error. Please check your internet connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String permissionError = 'Storage permission is required to download files.';
  static const String downloadError = 'Download failed. Please try again.';
  static const String downloadSuccess = 'Download completed successfully!';
  
  // Success Messages
  static const String downloadStarted = 'Download started...';
  static const String downloadCompleted = 'Download completed!';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 8.0;
} 