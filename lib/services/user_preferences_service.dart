import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  static const String _autoTrackOnDownloadKey = 'auto_track_on_download';

  bool _autoTrackOnDownload = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoTrackOnDownload = prefs.getBool(_autoTrackOnDownloadKey) ?? false;
    } catch (_) {
      _autoTrackOnDownload = false;
    } finally {
      _isInitialized = true;
    }
  }

  bool get autoTrackOnDownload => _autoTrackOnDownload;

  Future<void> setAutoTrackOnDownload(bool value) async {
    if (!_isInitialized) {
      await initialize();
    }

    _autoTrackOnDownload = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoTrackOnDownloadKey, value);
    } catch (_) {
      _autoTrackOnDownload = !value;
      rethrow;
    }
  }
}
