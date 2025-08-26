import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';
import 'anime_list_screen.dart';
import 'my_shows_screen.dart';
import 'login_screen.dart';

class HomepageScreen extends ConsumerWidget {
  final String? fcmToken;
  const HomepageScreen({super.key, this.fcmToken});
  
  @override
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              _buildAppTitle(),
              const Spacer(),
              Column(
                children: [
                  _buildAnimatedGif(),
                  _buildNavigationButtons(context),
                ],
              ),
              const Spacer()
            ],
          ),
        ),
      ),
    ),
  );
}


  Widget _buildAppTitle() {
    return Column(
      children: [
        Text(
          'ANIME',
          style: TextStyle(
            height: 0.5,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
            letterSpacing: 8,
            shadows: [
              Shadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        Text(
          'UPDATES',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 4,
          ),
        ),
      ],
    ).animate().fadeIn(
      duration: AppConstants.mediumAnimation,
    ).slideY(begin: -0.5);
  }

  Widget _buildAnimatedGif() {
    return Container(
      width: 280,
      height: 190,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.white.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: [0.0, 0.85, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'assets/images/choice.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.animation_rounded,
                size: 80,
                color: AppTheme.textSecondary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Row(
      children: [
        // New Releases Button
        Expanded(
          child: Container(
            height: 80,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    CustomPageTransitions.slideFromLeft(const AnimeListScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.new_releases_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'New Releases',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(
          duration: AppConstants.shortAnimation,
          delay: const Duration(milliseconds: 0),
        ).slideX(begin: -0.1),
        
        const SizedBox(width: 2),
        
        // My Shows Button
        Expanded(
          child: Container(
            height: 80,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.secondaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.secondaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Check if user is logged in
                  final isLoggedIn = AuthService.isLoggedIn;
                  if (isLoggedIn) {
                    Navigator.of(context).push(
                      CustomPageTransitions.slideFromRight(const MyShowsScreen()),
                    );
                  } else {
                    Navigator.of(context).push(
                      CustomPageTransitions.slideFromBottom(
                        LoginScreen(destination: const MyShowsScreen()),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.secondaryColor,
                              AppTheme.accentColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'My Shows',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(
          duration: AppConstants.shortAnimation,
          delay: const Duration(milliseconds: 0),
        ).slideX(begin: 0.1),
      ],
    );
  }
} 