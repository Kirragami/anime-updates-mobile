import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final String? downloadUrl;
  final String? targetVersion;
  final bool isReadyToInstall;

  const UpdateDialog({
    super.key,
    this.downloadUrl,
    this.targetVersion,
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
    final targetVersion = widget.targetVersion;
    if (downloadUrl == null || targetVersion == null || targetVersion.isEmpty) {
      setState(() {
        _statusText = 'Unable to determine the update version.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final downloadResult = await updateService.queueUpdateDownload(
        downloadUrl: downloadUrl,
        targetVersion: targetVersion,
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
    final layout = _UpdateDialogLayout.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: layout.insetHorizontal,
        vertical: layout.insetVertical,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxWidth),
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(layout.borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.contentPadding,
                  layout.contentPadding,
                  layout.contentPadding,
                  layout.contentPadding * 0.65,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReadyToInstall
                          ? 'Update Ready'
                          : 'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: layout.titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: layout.contentPadding * 0.5),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: layout.bodySize,
                        height: 1.35,
                      ),
                    ),
                    if (_isDownloading) ...[
                      SizedBox(height: layout.contentPadding * 0.65),
                      const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Gif sits flush with the dialog bottom; only actions get bottom inset.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: layout.gifPadding),
                    child: Image.asset(
                      'assets/gifs/gojo-dancing.gif',
                      height: layout.gifHeight,
                      width: layout.gifWidth,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomLeft,
                      gaplessPlayback: true,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.only(
                      right: layout.actionsPaddingRight,
                      bottom: layout.actionsPaddingBottom,
                    ),
                    child: _buildActions(layout),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(_UpdateDialogLayout layout) {
    if (_isDownloading) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: layout.buttonPaddingH,
              vertical: layout.buttonPaddingV,
            ),
            minimumSize: Size(layout.minButtonWidth, layout.minButtonHeight),
          ),
          child: Text(
            'Later',
            style: TextStyle(
              color: Colors.white54,
              fontSize: layout.buttonSize,
            ),
          ),
        ),
        SizedBox(width: layout.buttonGap),
        TextButton(
          onPressed:
              widget.isReadyToInstall ? _installUpdate : _startDownload,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: layout.buttonPaddingH,
              vertical: layout.buttonPaddingV,
            ),
            minimumSize: Size(layout.minButtonWidth, layout.minButtonHeight),
          ),
          child: Text(
            widget.isReadyToInstall ? 'Install' : 'Download',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: layout.buttonSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateDialogLayout {
  final double maxWidth;
  final double insetHorizontal;
  final double insetVertical;
  final double contentPadding;
  final double titleSize;
  final double bodySize;
  final double buttonSize;
  final double buttonPaddingH;
  final double buttonPaddingV;
  final double buttonGap;
  final double minButtonWidth;
  final double minButtonHeight;
  final double gifHeight;
  final double gifWidth;
  final double gifPadding;
  final double actionsPaddingRight;
  final double actionsPaddingBottom;
  final double borderRadius;

  const _UpdateDialogLayout({
    required this.maxWidth,
    required this.insetHorizontal,
    required this.insetVertical,
    required this.contentPadding,
    required this.titleSize,
    required this.bodySize,
    required this.buttonSize,
    required this.buttonPaddingH,
    required this.buttonPaddingV,
    required this.buttonGap,
    required this.minButtonWidth,
    required this.minButtonHeight,
    required this.gifHeight,
    required this.gifWidth,
    required this.gifPadding,
    required this.actionsPaddingRight,
    required this.actionsPaddingBottom,
    required this.borderRadius,
  });

  factory _UpdateDialogLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final shortest = size.shortestSide;
    final isLandscape = width > height;
    final compact = isLandscape && height < 500;
    final isTablet = shortest >= 600;
    final isLargeWide = width >= 1100 && shortest >= 600;
    final isTvLike = width >= 1400 || (shortest >= 800 && isLandscape);

    if (isTvLike) {
      return const _UpdateDialogLayout(
        maxWidth: 560,
        insetHorizontal: 48,
        insetVertical: 40,
        contentPadding: 32,
        titleSize: 26,
        bodySize: 17,
        buttonSize: 16,
        buttonPaddingH: 18,
        buttonPaddingV: 12,
        buttonGap: 12,
        minButtonWidth: 96,
        minButtonHeight: 48,
        gifHeight: 160,
        gifWidth: 132,
        gifPadding: 10,
        actionsPaddingRight: 20,
        actionsPaddingBottom: 20,
        borderRadius: 20,
      );
    }

    if (isLargeWide) {
      return const _UpdateDialogLayout(
        maxWidth: 500,
        insetHorizontal: 40,
        insetVertical: 32,
        contentPadding: 28,
        titleSize: 24,
        bodySize: 16,
        buttonSize: 15,
        buttonPaddingH: 16,
        buttonPaddingV: 11,
        buttonGap: 10,
        minButtonWidth: 88,
        minButtonHeight: 46,
        gifHeight: 140,
        gifWidth: 116,
        gifPadding: 8,
        actionsPaddingRight: 18,
        actionsPaddingBottom: 18,
        borderRadius: 18,
      );
    }

    if (isTablet) {
      return _UpdateDialogLayout(
        maxWidth: 460,
        insetHorizontal: isLandscape ? 48 : 40,
        insetVertical: compact ? 16 : 32,
        contentPadding: compact ? 20 : 26,
        titleSize: compact ? 20 : 22,
        bodySize: compact ? 14 : 15,
        buttonSize: 14,
        buttonPaddingH: 14,
        buttonPaddingV: 10,
        buttonGap: 10,
        minButtonWidth: 84,
        minButtonHeight: 44,
        gifHeight: compact ? 96 : 130,
        gifWidth: compact ? 80 : 108,
        gifPadding: 8,
        actionsPaddingRight: compact ? 14 : 16,
        actionsPaddingBottom: compact ? 12 : 16,
        borderRadius: 18,
      );
    }

    if (compact) {
      return const _UpdateDialogLayout(
        maxWidth: 520,
        insetHorizontal: 24,
        insetVertical: 12,
        contentPadding: 16,
        titleSize: 18,
        bodySize: 13,
        buttonSize: 13,
        buttonPaddingH: 12,
        buttonPaddingV: 8,
        buttonGap: 6,
        minButtonWidth: 72,
        minButtonHeight: 40,
        gifHeight: 84,
        gifWidth: 70,
        gifPadding: 8,
        actionsPaddingRight: 12,
        actionsPaddingBottom: 10,
        borderRadius: 14,
      );
    }

    final narrow = width < 360;
    return _UpdateDialogLayout(
      maxWidth: 400,
      insetHorizontal: narrow ? 16 : 24,
      insetVertical: 24,
      contentPadding: narrow ? 18 : 24,
      titleSize: narrow ? 18 : 20,
      bodySize: narrow ? 13 : 14,
      buttonSize: 14,
      buttonPaddingH: 12,
      buttonPaddingV: 8,
      buttonGap: 8,
      minButtonWidth: 72,
      minButtonHeight: 40,
      gifHeight: narrow ? 100 : 120,
      gifWidth: narrow ? 84 : 100,
      gifPadding: 8,
      actionsPaddingRight: 16,
      actionsPaddingBottom: 16,
      borderRadius: 16,
    );
  }
}
