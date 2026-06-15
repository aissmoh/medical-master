import 'package:flutter/material.dart';

class DelayedFadeSlide extends StatefulWidget {
  const DelayedFadeSlide({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<DelayedFadeSlide> createState() => _DelayedFadeSlideState();
}

class _DelayedFadeSlideState extends State<DelayedFadeSlide> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 700);
    const offsetY = 0.2;
    return AnimatedOpacity(
      duration: duration,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, offsetY),
        child: widget.child,
      ),
    );
  }
}
