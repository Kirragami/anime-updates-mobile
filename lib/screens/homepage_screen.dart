import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import 'anime_list_screen.dart';

class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.largePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated GIF
                _buildAnimatedGif(),
                // Navigation Buttons
                _buildNavigationButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildAnimatedGif() {
    return Container(
      width: 280,
      height: 190,
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
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Row(
      children: [
        // New Releases Button
        Expanded(
          child: Container(
            height: 80,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimeListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.new_releases_rounded, size: 24),
              label: const Text(
                'New Releases',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ).animate().fadeIn(
          duration: AppConstants.mediumAnimation,
          delay: const Duration(milliseconds: 600),
        ).slideX(begin: -0.3),
        
        const SizedBox(width: 2),
        
        // My Shows Button
        Expanded(
          child: Container(
            height: 80,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to My Shows screen when implemented
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('My Shows feature coming soon!'),
                    backgroundColor: AppTheme.secondaryColor,
                  ),
                );
              },
              icon: const Icon(Icons.favorite_rounded, size: 24),
              label: const Text(
                'My Shows',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(
                  color: AppTheme.secondaryColor,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ).animate().fadeIn(
          duration: AppConstants.mediumAnimation,
          delay: const Duration(milliseconds: 900),
        ).slideX(begin: 0.3),
      ],
    );
  }
} 