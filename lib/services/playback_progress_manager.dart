import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PlaybackProgressManager {
  static final PlaybackProgressManager _instance = PlaybackProgressManager._internal();
  factory PlaybackProgressManager() => _instance;
  PlaybackProgressManager._internal();

  Map<String, dynamic> _progressData = {};
  File? _file;
  bool _isInitialized = false;

  final ValueNotifier<Map<String, dynamic>> stateNotifier = ValueNotifier({});

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      String path = '${directory.path}/playbackProgress.json';
      _file = File(path);

      if (await _file!.exists()) {
        String contents = await _file!.readAsString();
        _progressData = jsonDecode(contents);
      } else {
        _progressData = {};
        await _saveToFile();
      }
      _isInitialized = true;
      _notifyListeners();
    } catch (e) {
      print('Error initializing PlaybackProgressManager: $e');
    }
  }

  Future<void> _saveToFile() async {
    if (_file == null) return;
    try {
      await _file!.writeAsString(jsonEncode(_progressData));
    } catch (e) {
      print('Error saving playback progress: $e');
    }
  }

  void _notifyListeners() {
    stateNotifier.value = Map<String, dynamic>.from(_progressData);
  }

  Future<void> saveProgress(String showId, String releaseId, int positionSec) async {
    if (!_isInitialized) return;

    if (!_progressData.containsKey(showId)) {
      _progressData[showId] = {
        'lastWatchedReleaseId': releaseId,
        'episodes': <String, dynamic>{}
      };
    }

    _progressData[showId]['lastWatchedReleaseId'] = releaseId;

    if (_progressData[showId]['episodes'] == null) {
      _progressData[showId]['episodes'] = <String, dynamic>{};
    }

    _progressData[showId]['episodes'][releaseId] = positionSec;

    _notifyListeners();
    await _saveToFile();
  }

  String? getLastWatchedReleaseId(String showId) {
    if (!_isInitialized || !_progressData.containsKey(showId)) return null;
    return _progressData[showId]['lastWatchedReleaseId'] as String?;
  }

  int getPosition(String showId, String releaseId) {
    if (!_isInitialized || !_progressData.containsKey(showId)) return 0;
    final episodes = _progressData[showId]['episodes'];
    if (episodes != null && episodes[releaseId] != null) {
      return episodes[releaseId] as int;
    }
    return 0;
  }

  void dispose() {
    stateNotifier.dispose();
  }
}
