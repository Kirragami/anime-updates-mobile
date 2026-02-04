import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_providers.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../models/download_state.dart';
import '../utils/page_transitions.dart';
import 'anime_list_screen.dart';
import 'my_shows_screen.dart';
import 'login_screen.dart';
import 'download_manager_screen.dart';
import 'downloaded_episodes_screen.dart';
import 'profile_screen.dart';

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
          child: Stack(
            children: [
              Padding(
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
             
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            
                    Consumer(
                      builder: (context, ref, child) {
                        final completedDownloads = ref.watch(completedDownloadsProvider);
                        final hasCompleted = completedDownloads.isNotEmpty;
                        if (!hasCompleted) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: 'Downloaded Episodes',
                          icon: const Icon(
                            Icons.movie_creation_rounded,
                            size: 28,
                            color: AppTheme.textPrimary,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              CustomPageTransitions.simpleSlide(
                                const DownloadedEpisodesScreen(),
                                fromRight: true,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                
                    Consumer(
                      builder: (context, ref, child) {
                        final activeDownloads = ref.watch(activeDownloadsProvider);
                        final activeCount = activeDownloads.length;
                        
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 32,
                                color: AppTheme.textPrimary,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  CustomPageTransitions.simpleSlide(
                                    const DownloadManagerScreen(),
                                    fromRight: true,
                                  ),
                                );
                              },
                            ),
                            if (activeCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    '$activeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
               
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        size: 31,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          CustomPageTransitions.simpleSlide(
                            const ProfileScreen(),
                            fromRight: true,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return const Column(
      children: [
        Text(
          'Anime',
          style: TextStyle(
            height: 0.9,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Updates',
          style: TextStyle(
            height: 0.9,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
            letterSpacing: 2,
          ),
        ),
      ],
    );
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
    return Consumer(
      builder: (context, ref, child) {
        final completedDownloads = ref.watch(completedDownloadsProvider);
        final hasCompletedDownloads = completedDownloads.length > 0;
        
        if (hasCompletedDownloads) {
          
          return Column(
            children: [
     
              Row(
                children: [
                  _buildNewReleasesButton(context),
                  const SizedBox(width: 2),
                  _buildMyShowsButton(context),
                ],
              ),
            ],
          );
        } else {
        
          return Row(
            children: [
              _buildNewReleasesButton(context),
              const SizedBox(width: 2),
              _buildMyShowsButton(context),
            ],
          );
        }
      },
    );
  }

  Widget _buildNewReleasesButton(BuildContext context) {
    return Expanded(
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
                CustomPageTransitions.simpleSlide(
                  const AnimeListScreen(),
                  fromRight: false,
                ),
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
                  const Text(
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
    )
        .animate()
        .fadeIn(
          duration: AppConstants.shortAnimation,
          delay: const Duration(milliseconds: 0),
        )
        .slideX(begin: -0.1);
  }

  Widget _buildMyShowsButton(BuildContext context) {
    return Expanded(
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
          
              final isLoggedIn = AuthService.isLoggedIn;
              if (isLoggedIn) {
                Navigator.of(context).push(
                  CustomPageTransitions.simpleSlide(
                    const MyShowsScreen(),
                    fromRight: true,
                  ),
                );
              } else {
                Navigator.of(context).push(
                  CustomPageTransitions.simpleFade(
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
                      gradient: AppTheme.secondaryGradient,
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
                  const Text(
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
    )
        .animate()
        .fadeIn(
          duration: AppConstants.shortAnimation,
          delay: const Duration(milliseconds: 100),
        )
        .slideX(begin: 0.1);
  }
}
