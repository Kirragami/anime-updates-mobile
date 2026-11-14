import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  static const String _autoTrackOnDownloadKey = 'auto_track_on_download';
  static const String _subtitleFontSizeKey = 'subtitle_font_size';
  static const int defaultSubtitleFontSize = 20;

  bool _autoTrackOnDownload = false;
  int _subtitleFontSize = defaultSubtitleFontSize;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoTrackOnDownload = prefs.getBool(_autoTrackOnDownloadKey) ?? false;
      _subtitleFontSize =
          prefs.getInt(_subtitleFontSizeKey) ?? defaultSubtitleFontSize;
    } catch (_) {
      _autoTrackOnDownload = false;
      _subtitleFontSize = defaultSubtitleFontSize;
    } finally {
      _isInitialized = true;
    }
  }

  bool get autoTrackOnDownload => _autoTrackOnDownload;

  int get subtitleFontSize => _subtitleFontSize;

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

  Future<void> setSubtitleFontSize(int value) async {
    if (!_isInitialized) {
      await initialize();
    }

    final previous = _subtitleFontSize;
    _subtitleFontSize = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_subtitleFontSizeKey, value);
    } catch (_) {
      _subtitleFontSize = previous;
      rethrow;
    }
  }
}
