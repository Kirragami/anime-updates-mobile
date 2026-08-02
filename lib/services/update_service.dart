import 'dart:io';
import 'package:dio/dio.dart';
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
  static const Set<String> _knownAbis = {
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
  };

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
        final baseDownloadUrl =
            data['downloadUrl'] as String? ?? _updateDownloadUrl;

        return {
          'success': true,
          'needUpdate': needUpdate,
          'latestVersion': data['latestVersion'] as String? ?? 'Unknown',
          'downloadUrl': await resolveDownloadUrl(baseDownloadUrl),
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

  Future<String?> getPreferredAbi() async {
    if (!Platform.isAndroid) return null;
    try {
      final abi =
          await _updateDownloadChannel.invokeMethod<String>('getPreferredAbi');
      if (abi != null && _knownAbis.contains(abi)) return abi;
    } on PlatformException {
      // Fall through to fat APK download.
    }
    return null;
  }

  /// Prefer `/download/{abi}`; fall back to the fat `/download` URL on 404.
  Future<String> resolveDownloadUrl(String baseDownloadUrl) async {
    final fatUrl = _normalizeFatDownloadUrl(baseDownloadUrl);
    final abi = await getPreferredAbi();
    if (abi == null) return fatUrl;

    final abiUrl = '$fatUrl/$abi';
    if (await _remoteFileExists(abiUrl)) {
      return abiUrl;
    }
    return fatUrl;
  }

  String _normalizeFatDownloadUrl(String downloadUrl) {
    var normalized = downloadUrl.trim();
    if (normalized.isEmpty) {
      normalized = _updateDownloadUrl;
    }
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');

    for (final abi in _knownAbis) {
      if (normalized.endsWith('/$abi')) {
        normalized =
            normalized.substring(0, normalized.length - abi.length - 1);
        break;
      }
    }
    return normalized;
  }

  Future<bool> _remoteFileExists(String url) async {
    try {
      final headResponse = await Dio().head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (headResponse.statusCode == 200 || headResponse.statusCode == 206) {
        return true;
      }
      if (headResponse.statusCode != 404 && headResponse.statusCode != 405) {
        return false;
      }
    } catch (_) {
      // Some hosts reject HEAD; try a lightweight GET next.
    }

    try {
      final getResponse = await Dio().get<List<int>>(
        url,
        options: Options(
          followRedirects: true,
          responseType: ResponseType.bytes,
          headers: const {'Range': 'bytes=0-0'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return getResponse.statusCode == 200 || getResponse.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> queueUpdateDownload({
    required String downloadUrl,
    required String targetVersion,
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

      final resolvedUrl = await resolveDownloadUrl(downloadUrl);
      final result = await _updateDownloadChannel
          .invokeMapMethod<String, dynamic>('enqueueUpdateDownload', {
        'downloadUrl': resolvedUrl,
        'targetVersion': targetVersion,
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

  Future<void> clearUpdateDownload() async {
    if (!Platform.isAndroid) return;

    try {
      await _updateDownloadChannel.invokeMethod('clearUpdateDownload');
    } on PlatformException {
      // Best-effort cleanup of a completed APK that is no longer needed.
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
