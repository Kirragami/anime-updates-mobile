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

  /// Initialize the speed limit service
  Future<void> initialize() async {
    await _speedLimitService.initialize();
  }

  /// Throttle download based on speed limit
  Future<void> _throttleDownload() async {
    if (!_speedLimitService.isSpeedLimited || !_isDownloading) return;

    final now = DateTime.now();
    final timeSinceLastSecond = now.difference(_lastSecondStart).inMilliseconds;

    // Reset counter every second
    if (timeSinceLastSecond >= 1000) {
      _bytesReceivedInCurrentSecond = 0;
      _lastSecondStart = now;
      return;
    }

    // Check if we've exceeded the speed limit for this second
    final maxBytesPerSecond = _speedLimitService.speedLimitBytesPerSecond;
    if (_bytesReceivedInCurrentSecond >= maxBytesPerSecond) {
      // Calculate how long to wait until the next second
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
        // Request multiple permissions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.manageExternalStorage,
          Permission.videos,
          Permission.audio,
        ].request();

        if (kDebugMode) {
          print('Permission statuses: $statuses');
        }

        // Check if any of the permissions are granted
        bool hasPermission = statuses.values.any((status) => status.isGranted);
        
        if (kDebugMode) {
          print('Has permission: $hasPermission');
        }
        
        return hasPermission;
      } catch (e) {
        if (kDebugMode) {
          print('Error requesting permissions: $e');
        }
        return false;
      }
    }
    return true;
  }

  Future<String?> getDownloadDirectory() async {
    try {
      if (kDebugMode) {
        print('Getting download directory...');
      }

      Directory? directory;
      if (Platform.isAndroid) {
        // Try to get external storage directory
        directory = await getExternalStorageDirectory();
        
        if (kDebugMode) {
          print('External storage directory: ${directory?.path}');
        }
        
        // If external storage is not available, fall back to app documents
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
      
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/AnimeDownloads');
        
        if (kDebugMode) {
          print('Download directory path: ${downloadDir.path}');
          print('Download directory exists: ${await downloadDir.exists()}');
        }
        
        if (!await downloadDir.exists()) {
          if (kDebugMode) {
            print('Creating download directory...');
          }
          await downloadDir.create(recursive: true);
          
          if (kDebugMode) {
            print('Download directory created successfully');
          }
        }
        
        return downloadDir.path;
      }
      
      if (kDebugMode) {
        print('No directory available');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting download directory: $e');
      }
      return null;
    }
  }

  Future<String?> downloadFile({
    required String url,
    required String filename,
    Function(int, int)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting download: $url to $filename');
      }

      // Initialize speed limit service
      await _speedLimitService.initialize();

      // Request permissions
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception(AppConstants.permissionError);
      }

      // Get download directory
      final downloadPath = await getDownloadDirectory();
      if (downloadPath == null) {
        throw Exception('Could not access download directory');
      }

      // Create safe filename
      final safeFilename = _createSafeFilename(filename);
      final filePath = '$downloadPath/$safeFilename';
      
      if (kDebugMode) {
        print('Full file path: $filePath');
        print('Speed limit: ${_speedLimitService.formattedSpeedLimit}');
      }

      // Reset speed limiting counters
      _bytesReceivedInCurrentSecond = 0;
      _lastSecondStart = DateTime.now();
      _isDownloading = true;

      // Download file with speed limiting
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) async {
          // Update speed limiting counter
          final newBytes = received - _bytesReceivedInCurrentSecond;
          if (newBytes > 0) {
            _bytesReceivedInCurrentSecond = received;
            
            // Apply throttling if needed
            await _throttleDownload();
          }
          
          // Call the original progress callback
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

      if (kDebugMode) {
        print('Download completed: $filePath');
        final file = File(filePath);
        print('File exists: ${await file.exists()}');
        print('File size: ${await file.length()} bytes');
      }

      return filePath;
    } catch (e) {
      _isDownloading = false;
      if (kDebugMode) {
        print('Download error: $e');
      }
      
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
    // Remove or replace invalid characters
    String safeName = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    // Ensure it has a proper extension
    if (!safeName.toLowerCase().endsWith('.torrent')) {
      safeName += '.torrent';
    }
    
    if (kDebugMode) {
      print('Safe filename: $safeName');
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
      
      if (kDebugMode) {
        print('Checking file: $filePath, exists: $exists');
      }
      
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking file existence: $e');
      }
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
        if (kDebugMode) {
          print('Opening file: $filePath');
        }
        final result = await OpenFile.open(filePath);
        if (kDebugMode) {
          print('Open file result: ${result.type}');
        }
        return result.type == ResultType.done;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening file: $e');
      }
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
          if (kDebugMode) {
            print('Deleted file: $filePath');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting file: $e');
      }
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
      // Ignore deletion errors
    }
  }
} 