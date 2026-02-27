import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class AnimatedPulseMarker extends StatefulWidget {
  final IconData iconData;
  final Color color;
  final double size;

  const AnimatedPulseMarker({
    super.key,
    required this.iconData,
    this.color = AppColors.primary,
    this.size = 40,
  });

  @override
  State<AnimatedPulseMarker> createState() => _AnimatedPulseMarkerState();
}

class _AnimatedPulseMarkerState extends State<AnimatedPulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse
            Container(
              width: widget.size * (1.0 + 0.5 * _controller.value),
              height: widget.size * (1.0 + 0.5 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                  alpha: 0.3 * (1.0 - _controller.value),
                ),
              ),
            ),
            // Inner circle
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.iconData,
                color: Colors.white,
                size: widget.size * 0.6,
              ),
            ),
          ],
        );
      },
    );
  }
}

class StyledStaticMarker extends StatelessWidget {
  final IconData iconData;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final double size;

  const StyledStaticMarker({
    super.key,
    required this.iconData,
    this.backgroundColor = AppColors.primary,
    this.iconColor = Colors.white,
    this.borderColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? backgroundColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(iconData, color: iconColor, size: size * 0.55),
      ),
    );
  }
}
