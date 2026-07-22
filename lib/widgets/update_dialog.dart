import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final String? downloadUrl;
  final bool isReadyToInstall;

  const UpdateDialog({
    super.key,
    this.downloadUrl,
    this.isReadyToInstall = false,
  });

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _isDownloading = false;
  late String _statusText;

  @override
  void initState() {
    super.initState();
    _statusText = widget.isReadyToInstall
        ? 'Update downloaded. Install it now?'
        : 'New version available!';
  }

  Future<void> _startDownload() async {
    final downloadUrl = widget.downloadUrl;
    if (downloadUrl == null) return;

    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final downloadResult = await updateService.queueUpdateDownload(
        downloadUrl: downloadUrl,
      );

      if (downloadResult['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      } else {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _statusText = downloadResult['message'] as String? ??
              'Unable to start download.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusText = 'Error occurred.';
      });
    }
  }

  Future<void> _installUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'Opening installer...';
    });

    try {
      final result =
          await ref.read(updateServiceProvider).openCompletedUpdate();
      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _isDownloading = false;
        _statusText = result['message'] as String? ??
            'Unable to open the update installer.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Unable to open the update installer.';
        });
      }
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
                  Text(
                    widget.isReadyToInstall
                        ? 'Update Ready'
                        : 'Update Available',
                    style: const TextStyle(
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
                    const LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                          child: const Text('Later',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      if (!_isDownloading) const SizedBox(width: 8),
                      if (!_isDownloading)
                        TextButton(
                          onPressed: widget.isReadyToInstall
                              ? _installUpdate
                              : _startDownload,
                          child: Text(
                              widget.isReadyToInstall ? 'Install' : 'Download',
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold)),
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
