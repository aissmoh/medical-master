import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/color_utils.dart';

class FloatingOrb extends StatefulWidget {
  const FloatingOrb({
    super.key,
    required this.size,
    required this.colors,
    required this.dx,
    required this.dy,
    required this.duration,
  });

  final double size;
  final List<Color> colors;
  final double dx;
  final double dy;
  final Duration duration;

  @override
  State<FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<FloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
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
        final t = _controller.value * math.pi * 2;
        final offset = Offset(math.sin(t) * widget.dx, math.cos(t) * widget.dy);
        return Transform.translate(offset: offset, child: child);
      },
      child: Container(
        height: widget.size,
        width: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: widget.colors),
          boxShadow: [
            BoxShadow(
              color: withOpacity(widget.colors.last, 0.4),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
      ),
    );
  }
}
