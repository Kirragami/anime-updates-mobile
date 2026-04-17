import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.downloadUrl,
  });

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = 'New version available!';
  final CancelToken _cancelToken = CancelToken();

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final downloadResult = await updateService.downloadUpdate(
        downloadUrl: widget.downloadUrl,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (downloadResult['success'] == true) {
        if (!mounted) return;
        setState(() {
          _statusText = 'Installing update...';
        });
        final installResult = await updateService.installUpdate(downloadResult['filePath']);
        if (installResult['success'] != true) {
          final message = installResult['message'] as String? ?? 'Unknown error';
          if (message.contains('Permission to install packages is required')) {
            openAppSettings();
          }
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _statusText = 'Download failed.';
        });
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // Download was cancelled on dispose, no action needed
        return;
      }
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusText = 'Error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Downloading... ${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Image.asset(
                    'assets/gifs/gojo-dancing.gif',
                    height: 120,
                    width: 100,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isDownloading)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Later', style: TextStyle(color: Colors.white54)),
                        ),
                      if (!_isDownloading)
                        const SizedBox(width: 8),
                      if (!_isDownloading)
                        TextButton(
                          onPressed: _startDownload,
                          child: const Text('Download', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                      if (_isDownloading)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
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
