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

  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

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
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> downloadUpdate({
    required String downloadUrl,
    required void Function(int, int) onProgress,
  }) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final filePath = '${cacheDir.path}/anime_updates.apk';


      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

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

      if (await file.exists()) {
        final length = await file.length();
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
      return {
        'success': false,
        'message': 'Download failed: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> installUpdate(String filePath) async {
    try {
      
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
      

      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          return {
            'success': false,
            'message': 'Permission to install packages is required. Please enable it in Settings.',
          };
        }
      }

      final result = await OpenFile.open(filePath);
      
      
      if (result.type == ResultType.done) {
        return {
          'success': true,
          'result': result,
          'message': 'APK opened for installation successfully',
        };
      } else {
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
      return {
        'success': false,
        'message': 'Failed to open file: ${e.toString()}',
      };
    }
  }
}