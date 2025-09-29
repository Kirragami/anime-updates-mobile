import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import '../constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'speed_limit_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  int _bytesReceivedInCurrentSecond = 0;
  DateTime _lastSecondStart = DateTime.now();
  bool _isDownloading = false;

  Future<void> initialize() async {
    await _speedLimitService.initialize();
  }

  Future<void> _throttleDownload() async {
    if (!_speedLimitService.isSpeedLimited || !_isDownloading) return;

    final now = DateTime.now();
    final timeSinceLastSecond = now.difference(_lastSecondStart).inMilliseconds;

    if (timeSinceLastSecond >= 1000) {
      _bytesReceivedInCurrentSecond = 0;
      _lastSecondStart = now;
      return;
    }

    final maxBytesPerSecond = _speedLimitService.speedLimitBytesPerSecond;
    if (_bytesReceivedInCurrentSecond >= maxBytesPerSecond) {
      final waitTime = 1000 - timeSinceLastSecond;
      if (waitTime > 0) {
        await Future.delayed(Duration(milliseconds: waitTime));
        _bytesReceivedInCurrentSecond = 0;
        _lastSecondStart = DateTime.now();
      }
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.manageExternalStorage,
          Permission.videos,
          Permission.audio,
        ].request();


        bool hasPermission = statuses.values.any((status) => status.isGranted);
        
        
        return hasPermission;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<String?> getDownloadDirectory() async {
    try {

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        
        
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/AnimeDownloads');
        
        
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
          
        }
        
        return downloadDir.path;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadFile({
    required String url,
    required String filename,
    Function(int, int)? onProgress,
  }) async {
    try {

      await _speedLimitService.initialize();

      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception(AppConstants.permissionError);
      }

      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) {
        throw Exception('Could not access download directory');
      }

      final safeFilename = _createSafeFilename(filename);
      final filePath = '$downloadPath/$safeFilename';
      

      _bytesReceivedInCurrentSecond = 0;
      _lastSecondStart = DateTime.now();
      _isDownloading = true;

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) async {
          final newBytes = received - _bytesReceivedInCurrentSecond;
          if (newBytes > 0) {
            _bytesReceivedInCurrentSecond = received;
            
            await _throttleDownload();
          }
          
          onProgress?.call(received, total);
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      _isDownloading = false;


      return filePath;
    } catch (e) {
      _isDownloading = false;
      
      if (e.toString().contains('SocketException')) {
        throw Exception(AppConstants.networkError);
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Download timeout. Please try again.');
      } else {
        throw Exception('Download failed: ${e.toString()}');
      }
    }
  }

  String _createSafeFilename(String filename) {
    String safeName = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    if (!safeName.toLowerCase().endsWith('.torrent')) {
      safeName += '.torrent';
    }
    
    
    return safeName;
  }

  Future<bool> checkFileExists(String title) async {
    try {
      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) return false;

      final safeFilename = _createSafeFilename(title);
      final filePath = '$downloadPath/$safeFilename';
      
      final file = File(filePath);
      final exists = await file.exists();
      
      
      return exists;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getExistingFilePath(String title) async {
    try {
      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) return null;

      final safeFilename = _createSafeFilename(title);
      final filePath = '$downloadPath/$safeFilename';
      
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> openFile(String title) async {
    try {
      final filePath = await getExistingFilePath(title);
      if (filePath != null) {
        final result = await OpenFile.open(filePath);
        return result.type == ResultType.done;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getAllDownloadedFiles() async {
    try {
      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) return [];

      final directory = Directory(downloadPath);
      if (!await directory.exists()) return [];

      final files = await directory.list().toList();
      return files
          .where((entity) => entity is File && entity.path.endsWith('.torrent'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteFile(String title) async {
    try {
      final filePath = await getExistingFilePath(title);
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
    }
  }

  Future<void> deleteAllDownloads() async {
    try {
      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) return;

      final directory = Directory(downloadPath);
      if (!await directory.exists()) return;

      final files = await directory.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.torrent')) {
          await entity.delete();
        }
      }
    } catch (e) {
    }
  }
} 