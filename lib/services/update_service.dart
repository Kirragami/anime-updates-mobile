import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import 'dio_client.dart';

class UpdateService {
  static const MethodChannel _updateDownloadChannel =
      MethodChannel('com.aura.anime_updates/updateDownload');
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

  Future<Map<String, dynamic>> queueUpdateDownload({
    required String downloadUrl,
  }) async {
    if (!Platform.isAndroid) {
      return {
        'success': false,
        'message': 'Background APK updates are only supported on Android.',
      };
    }

    try {
      var notificationPermission = await Permission.notification.status;
      if (notificationPermission.isDenied) {
        notificationPermission = await Permission.notification.request();
      }
      if (!notificationPermission.isGranted) {
        return {
          'success': false,
          'message':
              'Notification permission is required to notify you when the update is ready.',
        };
      }

      var installPermission = await Permission.requestInstallPackages.status;
      if (installPermission.isDenied) {
        installPermission = await Permission.requestInstallPackages.request();
      }
      if (!installPermission.isGranted) {
        return {
          'success': false,
          'message':
              'Permission to install packages is required. Please enable it in Settings.',
        };
      }

      final result = await _updateDownloadChannel
          .invokeMapMethod<String, dynamic>('enqueueUpdateDownload', {
        'downloadUrl': downloadUrl,
      });
      return Map<String, dynamic>.from(result ?? const {});
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Unable to start the update download.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to start the update download: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getUpdateDownloadStatus() async {
    if (!Platform.isAndroid) {
      return {'status': 'none'};
    }

    try {
      final result = await _updateDownloadChannel
          .invokeMapMethod<String, dynamic>('getUpdateDownloadStatus');
      return Map<String, dynamic>.from(result ?? const {'status': 'none'});
    } on PlatformException {
      return {'status': 'none'};
    }
  }

  Future<Map<String, dynamic>> openCompletedUpdate() async {
    if (!Platform.isAndroid) {
      return {
        'success': false,
        'message': 'APK installation is only supported on Android.',
      };
    }

    try {
      var installPermission = await Permission.requestInstallPackages.status;
      if (installPermission.isDenied) {
        installPermission = await Permission.requestInstallPackages.request();
      }
      if (!installPermission.isGranted) {
        return {
          'success': false,
          'message':
              'Permission to install packages is required. Please enable it in Settings.',
        };
      }

      final result = await _updateDownloadChannel
          .invokeMapMethod<String, dynamic>('openCompletedUpdate');
      return Map<String, dynamic>.from(result ?? const {});
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Unable to open the downloaded update.',
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
            'message':
                'Permission to install packages is required. Please enable it in Settings.',
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
