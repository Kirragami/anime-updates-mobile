import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Future<void> showTopToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color background = AppTheme.surfaceColor,
  Color foreground = AppTheme.textPrimary,
  Duration duration = const Duration(seconds: 2),
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  final animationKey = GlobalKey<AnimatedListState>();

  entry = OverlayEntry(
    builder: (ctx) {
      final padding = MediaQuery.of(ctx).padding;
      return SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: padding.top + 12,
              child: TweenAnimationBuilder<double>(
                key: animationKey,
                tween: Tween(begin: -20, end: 0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: AnimatedOpacity(
                      opacity: value == 0 ? 1 : 0.95,
                      duration: const Duration(milliseconds: 150),
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: background.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foreground, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            style: AppTheme.body1.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  overlay.insert(entry);

  // Auto remove after a delay with a small fade-out animation
  await Future.delayed(duration);
  try {
    entry.remove();
  } catch (_) {}
}


