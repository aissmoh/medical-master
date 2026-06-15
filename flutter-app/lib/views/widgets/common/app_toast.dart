import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AppToastType { success, error, info, warning }

class AppToast {
  AppToast._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    _removeCurrentToast();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppToastOverlay(
        title: title ?? _defaultTitle(type),
        message: message,
        style: _ToastStyle.fromType(type),
        onClose: _removeCurrentToast,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, _removeCurrentToast);
  }

  static String _defaultTitle(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return 'Success';
      case AppToastType.error:
        return 'Error';
      case AppToastType.info:
        return 'Info';
      case AppToastType.warning:
        return 'Warning';
    }
  }

  static void _removeCurrentToast() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.title,
    required this.message,
    required this.style,
    required this.onClose,
  });

  final String title;
  final String message;
  final _ToastStyle style;
  final VoidCallback onClose;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              decoration: BoxDecoration(
                                color: widget.style.accentColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  12,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: widget.style.iconBackgroundColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        widget.style.icon,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.title,
                                            style: const TextStyle(
                                              color: kTextPrimary,
                                              fontSize: 21,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.message,
                                            style: const TextStyle(
                                              color: kTextSecondary,
                                              fontSize: 14,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: widget.onClose,
                                      splashRadius: 20,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  const _ToastStyle({
    required this.accentColor,
    required this.iconBackgroundColor,
    required this.icon,
  });

  final Color accentColor;
  final Color iconBackgroundColor;
  final IconData icon;

  factory _ToastStyle.fromType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return const _ToastStyle(
          accentColor: Color(0xFF34C759),
          iconBackgroundColor: Color(0xFF34C759),
          icon: Icons.check_rounded,
        );
      case AppToastType.error:
        return const _ToastStyle(
          accentColor: Color(0xFFFF375F),
          iconBackgroundColor: Color(0xFFFF375F),
          icon: Icons.close_rounded,
        );
      case AppToastType.info:
        return const _ToastStyle(
          accentColor: kAccent2,
          iconBackgroundColor: kAccent2,
          icon: Icons.info_outline_rounded,
        );
      case AppToastType.warning:
        return const _ToastStyle(
          accentColor: Color(0xFFFFB020),
          iconBackgroundColor: Color(0xFFFFB020),
          icon: Icons.priority_high_rounded,
        );
    }
  }
}
