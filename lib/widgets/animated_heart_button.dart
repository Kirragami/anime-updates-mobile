import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedHeartButton extends StatefulWidget {
  final bool isTracked;
  final VoidCallback onPressed;
  // Optional size to allow reuse in different contexts. Defaults to a compact modern size.
  final double size;

  const AnimatedHeartButton({
    super.key,
    required this.isTracked,
    required this.onPressed,
    this.size = 44,
  });

  @override
  State<AnimatedHeartButton> createState() => _AnimatedHeartButtonState();
}

class _AnimatedHeartButtonState extends State<AnimatedHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTracked != widget.isTracked) {
      if (widget.isTracked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double buttonSize = widget.size;
    final double iconSize = buttonSize * 0.55; // proportionally sized icon

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Modern, subtle style: glassy base with gradient when active
            gradient: widget.isTracked
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B9A), Color(0xFFFF3366)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isTracked ? null : const Color(0x33FFFFFF),
            border: Border.all(
              color: widget.isTracked
                  ? const Color(0x33FFFFFF)
                  : Colors.white.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              if (widget.isTracked)
                BoxShadow(
                  color: const Color(0xFFFF3366).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: iconSize,
                ),
                Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: iconSize,
                )
                    .animate(
                      controller: _controller,
                    )
                    .fadeIn(
                      duration: const Duration(milliseconds: 180),
                    )
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.elasticOut,
                    ),
              ],
            ),
          ),
        ),
      ),
    ).animate(controller: _controller).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.1, 1.1),
          curve: Curves.elasticOut,
        );
  }
}