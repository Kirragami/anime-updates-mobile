import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_widget.dart' as error_widgets;
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import '../services/services.dart';
import 'homepage_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  double _downloadSpeedLimit = 0.0; 
  final TextEditingController _speedController = TextEditingController();
  bool _isLoadingSpeedLimit = true;
  
  bool _isCheckingUpdate = false;
  bool _updateAvailable = false;
  String _updateStatus = '';
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSpeedLimit();
  }

  Future<void> _loadSpeedLimit() async {
    try {
      final speedLimitService = ref.read(speedLimitServiceProvider);
      await speedLimitService.initialize();
      setState(() {
        _downloadSpeedLimit = speedLimitService.speedLimit;
        _speedController.text = _downloadSpeedLimit.toString();
        _isLoadingSpeedLimit = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSpeedLimit = false;
      });
    }
  }

  Future<void> _saveSpeedLimit() async {
    try {
      final speedLimitService = ref.read(speedLimitServiceProvider);
      await speedLimitService.setSpeedLimit(_downloadSpeedLimit);
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _speedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: userAsync.when(
                  data: (user) => _buildProfileContent(user),
                  loading: () => _buildLoadingContent(),
                  error: (error, stack) => _buildErrorContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 14,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(dynamic user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (user != null) _buildProfileHeader(user),
          if (user != null) const SizedBox(height: 20),
          _buildSettingsList(),
          const SizedBox(height: 20),
          if (user != null) _buildLogoutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return  Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Column(
      children: [
        _buildSettingsGroup(
          'Notifications',
          [
            _buildSettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Receive notifications for new episodes',
              trailing: Switch.adaptive(
                value: _pushNotificationsEnabled,
                onChanged: (value) =>
                    setState(() => _pushNotificationsEnabled = value),
                activeColor: AppTheme.primaryColor,
              ),
            ),
            _buildSettingsItem(
              icon: Icons.notifications_active_outlined,
              title: 'All Notifications',
              subtitle: 'Enable or disable all notifications',
              trailing: Switch.adaptive(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                    _pushNotificationsEnabled = value;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        // const SizedBox(height: 20),
        // _buildSettingsGroup(
        //   'Download Settings',
        //   [
        //     _buildDownloadSpeedItem(),
        //   ],
        // ),
        const SizedBox(height: 20),
        _buildSettingsGroup(
          'App Updates',
          [
            _buildCheckUpdateItem(),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDownloadSpeedItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.speed_outlined,
            color: Colors.white.withOpacity(0.8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download Speed Limit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isLoadingSpeedLimit 
                    ? 'Loading speed limit...'
                    : 'Set maximum download speed in KB/s',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCustomSlider(),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _speedController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'KB/s',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                        ),
                        onChanged: (value) {
                          final newValue = double.tryParse(value);
                          if (newValue != null &&
                              newValue >= 0 &&
                              newValue <= 50000) {
                            setState(() {
                              _downloadSpeedLimit = newValue;
                            });
                            _saveSpeedLimit();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection() {
    return GestureDetector(
      onTap: () => _showLogoutDialog(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: _buildSettingsItem(
          icon: Icons.logout_outlined,
          title: 'Logout',
          subtitle: 'Sign out of your account',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.white.withOpacity(0.4),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSlider() {
  return Row(
    children: [
      GestureDetector(
        onTap: () {
          if (_downloadSpeedLimit > 0) {
            setState(() {
              _downloadSpeedLimit =
                  (_downloadSpeedLimit - 100).clamp(0, 50000);
              _speedController.text = _downloadSpeedLimit.toString();
            });
            _saveSpeedLimit();
          }
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor, 
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.remove,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      const SizedBox(width: 12),

      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final percentage = (_downloadSpeedLimit / 50000).clamp(0.0, 1.0);
            final thumbPosition = percentage * trackWidth;

            return GestureDetector(
              onTapDown: (details) {
                final localPosition = details.localPosition;
                final newPercentage =
                    (localPosition.dx / trackWidth).clamp(0.0, 1.0);
                setState(() {
                  _downloadSpeedLimit =
                      (newPercentage * 50000).clamp(0, 50000);
                  _speedController.text = _downloadSpeedLimit.toString();
                });
                _saveSpeedLimit();
              },
              onPanUpdate: (details) {
                final localPosition = details.localPosition;
                final newPercentage =
                    (localPosition.dx / trackWidth).clamp(0.0, 1.0);
                setState(() {
                  _downloadSpeedLimit =
                      (newPercentage * 50000).clamp(0, 50000);
                  _speedController.text = _downloadSpeedLimit.toString();
                });
                _saveSpeedLimit();
              },
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.grey.shade300,
                      ),
                    ),
                    Container(
                      width: thumbPosition,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: AppTheme.primaryColor, 
                      ),
                    ),
                    Positioned(
                      left: (thumbPosition - 12).clamp(0.0, trackWidth - 24), 
                      top: 8,                 
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 12),

      GestureDetector(
        onTap: () {
          if (_downloadSpeedLimit < 50000) {
            setState(() {
              _downloadSpeedLimit =
                  (_downloadSpeedLimit + 100).clamp(0, 50000);
              _speedController.text = _downloadSpeedLimit.toString();
            });
            _saveSpeedLimit();
          }
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor, 
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    ],
  );
}


  Widget _buildLogoutButton() {
    return _buildLogoutSection();
  }

  Widget _buildLoadingContent() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildErrorContent() {
    return error_widgets.CustomErrorWidget(
      message: 'Failed to load profile',
      onRetry: () {
        ref.invalidate(authProvider);
      },
      showRetryButton: true,
    );
  }

  Widget _buildCheckUpdateItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_outlined,
                color: Colors.white.withOpacity(0.8),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check for Updates',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isCheckingUpdate 
                        ? 'Checking for updates...' 
                        : _updateStatus.isEmpty 
                          ? 'Check for the latest version' 
                          : _updateStatus,
                      style: TextStyle(
                        color: _updateAvailable 
                          ? AppTheme.primaryColor 
                          : Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: _updateAvailable 
                          ? FontWeight.bold 
                          : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCheckingUpdate)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              else if (_updateAvailable && !_isDownloading)
                TextButton(
                  onPressed: _downloadUpdate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text(
                    'Download',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (!_isDownloading)
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  onPressed: _checkForUpdate,
                ),
            ],
          ),
          if (_isDownloading)
            Column(
              children: [
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: AppTheme.surfaceColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloading update... ${(_downloadProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = '';
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdate();

      if (result['success']) {
        if (result['needUpdate']) {
          setState(() {
            _updateAvailable = true;
            _updateStatus = 'New version available!';
          });
        } else {
          setState(() {
            _updateAvailable = false;
            _updateStatus = 'Your version is up to date';
          });
        }
      } else {
        setState(() {
          _updateStatus = result['message'] ?? 'Failed to check for updates';
        });
      }
    } catch (e) {
      setState(() {
        _updateStatus = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  Future<void> _downloadUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      
      final checkResult = await updateService.checkForUpdate();
      
      if (!checkResult['success'] || !checkResult['needUpdate']) {
        setState(() {
          _isDownloading = false;
          _updateStatus = 'No update available';
        });
        return;
      }
      
      final downloadUrl = checkResult['downloadUrl'];
      
      final downloadResult = await updateService.downloadUpdate(
        downloadUrl: downloadUrl,
        onProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (downloadResult['success']) {
        final filePath = downloadResult['filePath'];
        final installResult = await updateService.installUpdate(filePath);
        
        if (installResult['success']) {
        } else {
          if (mounted) {
            final message = installResult['message'] as String? ?? 'Unknown error';
            if (message.contains('Permission to install packages is required')) {
              openAppSettings();
            }
          }
        }
      } else {
      }
    } catch (e) {
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Confirm Sign Out',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Text(
                    'Are you sure you want to sign out of your account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: AppTheme.textSecondary.withOpacity(0.2),
                ),
                const SizedBox(height: 0),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppTheme.textSecondary.withOpacity(0.2),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await ref.read(authNotifierProvider).logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              CustomPageTransitions.fadeWithScale(
                                  const HomepageScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
