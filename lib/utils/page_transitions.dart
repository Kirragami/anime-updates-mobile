import 'package:flutter/material.dart';

class CustomPageTransitions {
  // Slide from right with fade - OPTIMIZED
  static PageRouteBuilder slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.3, 0.0); // Reduced from 1.0 for faster animation
        const end = Offset.zero;
        const curve = Curves.easeOut; // Simpler curve

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250), // Reduced from 400ms
    );
  }

  // Slide from left with fade - OPTIMIZED
  static PageRouteBuilder slideFromLeft(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-0.3, 0.0); // Reduced from -1.0 for faster animation
        const end = Offset.zero;
        const curve = Curves.easeOut; // Simpler curve

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250), // Reduced from 400ms
    );
  }

  // Slide from bottom with scale and fade - OPTIMIZED
  static PageRouteBuilder slideFromBottom(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.3); // Reduced from 1.0 for faster animation
        const end = Offset.zero;
        const curve = Curves.easeOut; // Simpler curve

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var scaleAnimation = animation.drive(
          Tween(begin: 0.95, end: 1.0).chain( // Reduced scale range for better performance
            CurveTween(curve: Curves.easeOut),
          ),
        );
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300), // Reduced from 500ms
    );
  }

  // Fade with scale - OPTIMIZED
  static PageRouteBuilder fadeWithScale(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var scaleAnimation = animation.drive(
          Tween(begin: 0.95, end: 1.0).chain( // Reduced scale range for better performance
            CurveTween(curve: Curves.easeOut), // Simpler curve
          ),
        );
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200), // Reduced from 300ms
    );
  }

  // Hero-like transition with slide - OPTIMIZED
  static PageRouteBuilder heroSlide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.15); // Reduced from 0.3 for faster animation
        const end = Offset.zero;
        const curve = Curves.easeOut; // Simpler curve

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var scaleAnimation = animation.drive(
          Tween(begin: 0.98, end: 1.0).chain( // Reduced scale range for better performance
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250), // Reduced from 450ms
    );
  }

  // Elastic bounce transition - OPTIMIZED
  static PageRouteBuilder elasticBounce(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var scaleAnimation = animation.drive(
          Tween(begin: 0.3, end: 1.0).chain( // Reduced from 0.0 for better performance
            CurveTween(curve: Curves.easeOut), // Changed from elasticOut for better performance
          ),
        );
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300), // Reduced from 800ms
    );
  }

  // NEW: Simple fade transition for maximum performance
  static PageRouteBuilder simpleFade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 150), // Fastest transition
    );
  }

  // NEW: Simple slide transition for maximum performance
  static PageRouteBuilder simpleSlide(Widget page, {bool fromRight = true}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final begin = Offset(fromRight ? 0.2 : -0.2, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 200), // Fast transition
    );
  }
} 