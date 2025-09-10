import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/page_transitions.dart';
import 'homepage_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _particleController;
  late AnimationController _gradientController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _gradientAnimation;

  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _gradientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );
  }

  void _initializeParticles() {
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 0.5 + 0.1,
        opacity: random.nextDouble() * 0.6 + 0.2,
      ));
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
    _particleController.repeat();
    _gradientController.repeat(reverse: true);

    // Navigate to homepage after 3 seconds (reduced for better UX)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CustomPageTransitions.simpleFade(const HomepageScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.surfaceColor,
              AppTheme.primaryColor.withOpacity(0.1),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated gradient overlay
            AnimatedBuilder(
              animation: _gradientAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withOpacity(_gradientAnimation.value * 0.1),
                        AppTheme.secondaryColor.withOpacity(_gradientAnimation.value * 0.05),
                        AppTheme.accentColor.withOpacity(_gradientAnimation.value * 0.08),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Floating particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(_particles, _particleController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // App logo/icon with animation
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: AppTheme.secondaryColor.withOpacity(0.3),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.animation_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // App title with slide animation
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Text(
                                  'ANIME',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: 8,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.primaryColor.withOpacity(0.5),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                               const Text(
                                  'UPDATES',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Discover • Download • Enjoy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary.withOpacity(0.8),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(flex: 2),

                    // Loading indicator
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your anime world...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double angle;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  }) : angle = math.Random().nextDouble() * 2 * math.pi;
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      // Calculate new position based on animation
      final newX = (particle.x + math.cos(particle.angle) * particle.speed * animationValue) % 1.0;
      final newY = (particle.y + math.sin(particle.angle) * particle.speed * animationValue) % 1.0;

      // Create pulsing effect
      final pulse = (math.sin(animationValue * 2 * math.pi + particle.angle) + 1) / 2;
      final currentOpacity = particle.opacity * (0.5 + pulse * 0.5);

      paint.color = AppTheme.primaryColor.withOpacity(currentOpacity);
      canvas.drawCircle(
        Offset(newX * size.width, newY * size.height),
        particle.size * (0.8 + pulse * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
