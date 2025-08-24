import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedHeartButton extends StatefulWidget {
  final bool isTracked;
  final VoidCallback onPressed;

  const AnimatedHeartButton({
    super.key,
    required this.isTracked,
    required this.onPressed,
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
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.isTracked
                  ? Colors.pink.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.isTracked
                ? const LinearGradient(
                    colors: [Colors.pink, Colors.redAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.grey, Colors.blueGrey],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Empty heart outline
                Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 28,
                ),
                // Filled heart that animates in/out
                Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 28,
                )
                    .animate(
                      controller: _controller,
                    )
                    .fadeIn(
                      duration: const Duration(milliseconds: 200),
                    )
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                    ),
              ],
            ),
          ),
        ),
      ),
    ).animate(
      controller: _controller,
    ).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.2, 1.2),
      curve: Curves.elasticOut,
    );
  }
}