import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import 'homepage_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  double _downloadSpeedLimit = 1000.0; // KB/s
  final TextEditingController _speedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speedController.text = _downloadSpeedLimit.toString();
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
          // Back button without background - matching anime list style
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
          _buildProfileHeader(user),
          const SizedBox(height: 20),
          _buildSettingsList(),
          const SizedBox(height: 20),
          _buildLogoutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          // Profile Avatar
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
          // User info section
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
                const SizedBox(height: 4),
                Text(
                  'Member since 2025',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
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
                onChanged: (value) => setState(() => _pushNotificationsEnabled = value),
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
        const SizedBox(height: 20),
        _buildSettingsGroup(
          'Download Settings',
          [
            _buildDownloadSpeedItem(),
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
                  'Set maximum download speed in KB/s',
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
                          if (newValue != null && newValue >= 0 && newValue <= 10000) {
                            setState(() {
                              _downloadSpeedLimit = newValue;
                            });
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
        // Minus button
        GestureDetector(
          onTap: () {
            if (_downloadSpeedLimit > 0) {
              setState(() {
                _downloadSpeedLimit = (_downloadSpeedLimit - 100).clamp(0, 10000);
                _speedController.text = _downloadSpeedLimit.toString();
              });
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.remove,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Slider track
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final percentage = (_downloadSpeedLimit / 10000).clamp(0.0, 1.0);
              final thumbPosition = percentage * trackWidth;
              
              return GestureDetector(
                onTapDown: (details) {
                  final localPosition = details.localPosition;
                  final newPercentage = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
                  setState(() {
                    _downloadSpeedLimit = (newPercentage * 10000).clamp(0, 10000);
                    _speedController.text = _downloadSpeedLimit.toString();
                  });
                },
                onPanUpdate: (details) {
                  final localPosition = details.localPosition;
                  final newPercentage = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
                  setState(() {
                    _downloadSpeedLimit = (newPercentage * 10000).clamp(0, 10000);
                    _speedController.text = _downloadSpeedLimit.toString();
                  });
                },
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: Stack(
                    children: [
                      // Filled portion
                      Container(
                        width: thumbPosition,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      // Thumb
                      Positioned(
                        left: thumbPosition - 20,
                        top: -17,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.3),
                              radius: 0.8,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
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
        // Plus button
        GestureDetector(
          onTap: () {
            if (_downloadSpeedLimit < 10000) {
              setState(() {
                _downloadSpeedLimit = (_downloadSpeedLimit + 100).clamp(0, 10000);
                _speedController.text = _downloadSpeedLimit.toString();
              });
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorColor,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Confirm Sign Out',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                const Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                // Divider line
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 0),
                // Buttons row
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    // Sign Out button
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await ref.read(authNotifierProvider).logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              CustomPageTransitions.fadeWithScale(const HomepageScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                        child: Text(
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
