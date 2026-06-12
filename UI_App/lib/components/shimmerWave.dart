import 'package:flutter/material.dart';
class ShimmerWave extends StatefulWidget {
  final Widget child;
  const ShimmerWave({super.key, required this.child});

  @override
  State<ShimmerWave> createState() => _ShimmerWaveState();
}

class _ShimmerWaveState extends State<ShimmerWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Speed of the wave
    )..repeat();
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
        // Translate the gradient from left (-1) to right (2) across the bounds
        final x = -1.0 + (_controller.value * 3.0);

        return ShaderMask(
          // srcATop ensures the wave only paints OVER the opaque parts (the shapes)
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.8), // The bright "wave" highlight
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
