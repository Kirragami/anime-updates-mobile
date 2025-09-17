import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'dio_client.dart';

class UpdateService {
  static const String _baseUrl = AppConstants.baseUrl;
  static const String _checkUpdateEndpoint = AppConstants.checkUpdateEndpoint;
  static const String _updateDownloadUrl = AppConstants.updateDownloadUrl;

  static String get checkUpdateUrl => '$_baseUrl$_checkUpdateEndpoint';

  /// Check if an update is available
  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      // Get the current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Make the API call to check for updates
      final response = await dioClient.post(
        checkUpdateUrl,
        data: {
          'installedVersion': currentVersion,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final needUpdate = data['needUpdate'] as bool? ?? false;
        
        return {
          'success': true,
          'needUpdate': needUpdate,
          'latestVersion': data['latestVersion'] as String? ?? 'Unknown',
          'downloadUrl': data['downloadUrl'] as String? ?? _updateDownloadUrl,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to check for updates',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('UpdateService.checkForUpdate error: $e');
      }
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Download the update APK file
  Future<Map<String, dynamic>> downloadUpdate({
    required String downloadUrl,
    required void Function(int, int) onProgress,
  }) async {
    try {
      // Get cache directory for downloading the APK (better than temporary directory)
      final cacheDir = await getTemporaryDirectory();
      final filePath = '${cacheDir.path}/anime_updates.apk';

      if (kDebugMode) {
        print('Downloading APK to: $filePath');
      }

      // Delete any existing file with the same name
      final file = File(filePath);
      if (await file.exists()) {
        if (kDebugMode) {
          print('Deleting existing APK file');
        }
        await file.delete();
      }

      // Download with progress tracking
      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // Verify file was downloaded
      if (await file.exists()) {
        final length = await file.length();
        if (kDebugMode) {
          print('APK downloaded successfully. File size: $length bytes');
        }
        if (length == 0) {
          return {
            'success': false,
            'message': 'Downloaded file is empty',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Failed to save downloaded file',
        };
      }

      return {
        'success': true,
        'filePath': filePath,
      };
    } catch (e) {
      if (kDebugMode) {
        print('UpdateService.downloadUpdate error: $e');
      }
      return {
        'success': false,
        'message': 'Download failed: ${e.toString()}',
      };
    }
  }

  /// Open the downloaded APK file for installation
  Future<Map<String, dynamic>> installUpdate(String filePath) async {
    try {
      if (kDebugMode) {
        print('Attempting to open APK file: $filePath');
      }
      
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'APK file not found',
        };
      }
      
      final length = await file.length();
      if (length == 0) {
        return {
          'success': false,
          'message': 'APK file is empty',
        };
      }
      
      if (kDebugMode) {
        print('APK file size: $length bytes');
      }

      // Check and request install packages permission
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        if (kDebugMode) {
          print('Install packages permission not granted');
        }
        // Try to request the permission
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          return {
            'success': false,
            'message': 'Permission to install packages is required. Please enable it in Settings.',
          };
        }
      }

      // Try to open the file
      final result = await OpenFile.open(filePath);
      
      if (kDebugMode) {
        print('OpenFile result: ${result.message}, type: ${result.type}');
      }
      
      // Check if opening was successful
      if (result.type == ResultType.done) {
        return {
          'success': true,
          'result': result,
          'message': 'APK opened for installation successfully',
        };
      } else {
        // Handle specific error cases
        if (result.type == ResultType.error) {
          return {
            'success': false,
            'result': result,
            'message': 'Failed to open APK for installation: ${result.message}',
          };
        } else {
          return {
            'success': false,
            'result': result,
            'message': 'Unable to open APK: ${result.message}',
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('UpdateService.installUpdate error: $e');
      }
      return {
        'success': false,
        'message': 'Failed to open file: ${e.toString()}',
      };
    }
  }
}