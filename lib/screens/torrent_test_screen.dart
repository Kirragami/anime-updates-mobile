import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dtorrent_task/dtorrent_task.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dtorrent_task/src/task.dart';
import 'package:dtorrent_task/src/task_events.dart';
import 'package:events_emitter2/events_emitter2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TorrentTestScreen extends StatefulWidget {
  const TorrentTestScreen({super.key});

  @override
  State<TorrentTestScreen> createState() => _TorrentTestScreenState();
}

class _TorrentTestScreenState extends State<TorrentTestScreen> {
  // Track status and progress for 3 torrents
  List<String> _statuses = ['Ready', 'Ready', 'Ready'];
  List<double> _progresses = [0.0, 0.0, 0.0];
  List<bool> _isRunning = [false, false, false];
  static const _channel = MethodChannel("com.aura.anime_updates/torrent");

  Future<void> _startDownload(int index) async {
    try {
      setState(() {
        _statuses[index] = 'Initializing...';
        _isRunning[index] = true;
      });

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();

        if (kDebugMode) {
          print('External storage directory: ${directory?.path}');
        }

        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
          if (kDebugMode) {
            print('Using app documents directory: ${directory.path}');
          }
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
        if (kDebugMode) {
          print('Using app documents directory: ${directory.path}');
        }
      }

      // Path to the torrent file (you need to place a .torrent file at this location)
      // final torrentPath = '${directory.path}/AnimeDownloads/Dainanaoji.torrent';
      final savePath = '${directory.path}/TorrentFileDownloads';
      // final fileName = '[SubsPlease] Dainanaoji - 20 (1080p) [95499314].mkv';

      final fileName = ['[SubsPlease] Dekin no Mogura - 09 (1080p) [0F4008C6].mkv',
                        '[SubsPlease] Puniru wa Kawaii Slime - 21 (1080p) [2E41DD67].mkv',
                        '[SubsPlease] Jibaku Shounen Hanako-kun S2 - 21 (1080p) [135C9E17].mkv'];

      final magnetUrl = ['magnet:?xt=urn:btih:72dc4f32a19a0f9a25a052496b66abdc1e58f7b0&dn=%5BSubsPlease%5D%20Dekin%20no%20Mogura%20-%2009%20%281080p%29%20%5B0F4008C6%5D.mkv&tr=http%3A%2F%2Fnyaa.tracker.wf%3A7777%2Fannounce&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce', 
                         'magnet:?xt=urn:btih:da357ab15da1370a0098ef604f731f07e7682c71&dn=%5BSubsPlease%5D%20Puniru%20wa%20Kawaii%20Slime%20-%2021%20%281080p%29%20%5B2E41DD67%5D.mkv&tr=http%3A%2F%2Fnyaa.tracker.wf%3A7777%2Fannounce&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce', 
                         'magnet:?xt=urn:btih:77e74f364dcc8850c98678ec234df73d56b292a9&dn=%5BSubsPlease%5D%20Jibaku%20Shounen%20Hanako-kun%20S2%20-%2021%20%281080p%29%20%5B135C9E17%5D.mkv&tr=http%3A%2F%2Fnyaa.tracker.wf%3A7777%2Fannounce&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce'];
      
      // Check if torrent file exists
      // final file = File(torrentPath[index]);
      // if (!await file.exists()) {
      //   setState(() {
      //     _statuses[index] = 'Error: Torrent file not found at $torrentPath';
      //     _isRunning[index] = false;
      //   });
      //   return;
      // }

      // Create download directory if it doesn't exist
      await Directory(savePath).create(recursive: true);

      await startTorrent(magnetUrl[index], savePath, fileName[index], index.toString());
      _isRunning[index] = true;

      setState(() {
        _statuses[index] = 'Downloading...';
      });
      _updateProgress(index);
    } catch (e) {
      setState(() {
        _statuses[index] = 'Error: $e';
        _isRunning[index] = false;
      });
    }
  }

  static Future<void> startTorrent(String magnetUrl, String savePath, String fileName, String releaseId) async {
    await _channel.invokeMethod("addTorrent", {
      "releaseId": releaseId,
      "magnetUrl": magnetUrl,
      "savePath": savePath,
      "fileName": fileName
    });
  }

  void _updateProgress(int index) async {
    if (!_isRunning[index]) return;

    try {
      final progress = await getProgress(index.toString());
      setState(() {
        _progresses[index] = progress;
        _statuses[index] = 'Downloading... ${(progress)}%';
      });
    } catch (e) {
      setState(() {
        _statuses[index] = 'Error while getting progress: $e';
        _isRunning[index] = false;
      });
      return;
    }

    // schedule next poll
    Future.delayed(const Duration(seconds: 1), () => _updateProgress(index));
  }

  static Future<double> getProgress(String releaseId) async {
    try {
      final progress = await _channel.invokeMethod("getProgress", {
        "releaseId": releaseId
      });
      return double.parse(progress.toStringAsFixed(2));
    } catch (e) {
      print("Error getting progress: $e");
      return 0.0;
    }
  }

  static Future<void> stopTorrent() async {
    await _channel.invokeMethod("stopTorrent");
  }

  Future<void> _pauseDownload(int index) async {
    await pauseTorrent(index.toString());
    setState(() {
      _statuses[index] = "Paused...";
      _isRunning[index] = false;
    });
  }

  static Future<void> pauseTorrent(String releaseId) async {
    await _channel.invokeMethod("pauseTorrent", {
      "releaseId": releaseId
    });
  }

  Future<void> _resumeDownload(int index) async {
    await resumeTorrent(index.toString());
    setState(() {
      _statuses[index] = "Downloading...";
      _isRunning[index] = true;
    });
    _updateProgress(index);
  }

  static Future<void> resumeTorrent(String releaseId) async {
    await _channel.invokeMethod("resumeTorrent", {
      "releaseId": releaseId
    });
  }

  void _stopDownload(int index) async {
    await stopTorrent();
    setState(() {
      _statuses[index] = 'Stopped';
      _isRunning[index] = false;
    });
  }

  Future<void> _pauseAllDownloads() async {

    await _channel.invokeMethod("pauseAllTorrents");
    setState(() {
      for (int i = 0; i < 3; i++) {
        if (_isRunning[i]) {
          _statuses[i] = "Paused...";
          _isRunning[i] = false;
        }
      }
    });
  }

  Future<void> _resumeAllDownloads() async {
    await _channel.invokeMethod("resumeAllTorrents");
    for (int i = 0; i < 3; i++) {
      if (!_isRunning[i]) {
        setState(() {
          _statuses[i] = "Downloading...";
          _isRunning[i] = true;
        });
      }
    }
  }

  Widget _buildTorrentSection(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Torrent ${index + 1} Status: ${_statuses[index]}'),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: _progresses[index] / 100.0),
        const SizedBox(height: 10),
        Text('${(_progresses[index])}%'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ElevatedButton(
                onPressed: _isRunning[index] ? null : () => _startDownload(index),
                child: const Text('Start'),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ElevatedButton(
                onPressed: _isRunning[index] ? () => _pauseDownload(index) : null,
                child: const Text('Pause'),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ElevatedButton(
                onPressed: _isRunning[index] ? null : () => _resumeDownload(index),
                child: const Text('Resume'),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ElevatedButton(
                onPressed: _isRunning[index] ? () => _stopDownload(index) : null,
                child: const Text('Stop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Torrent Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildTorrentSection(0),
            const Divider(),
            _buildTorrentSection(1),
            const Divider(),
            _buildTorrentSection(2),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: ElevatedButton(
                    onPressed: _isRunning.any((running) => running) ? _pauseAllDownloads : null,
                    child: const Text('Pause All'),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: ElevatedButton(
                    onPressed: _isRunning.any((running) => !running) ? _resumeAllDownloads : null,
                    child: const Text('Resume All'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
