import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EmergencyAlertFrame extends StatefulWidget {
  const EmergencyAlertFrame({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  State<EmergencyAlertFrame> createState() => _EmergencyAlertFrameState();
}

class _EmergencyAlertFrameState extends State<EmergencyAlertFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant EmergencyAlertFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (widget.active)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final opacity = 0.46 + (_controller.value * 0.44);
                  final width = 4.0 + (_controller.value * 2.5);
                  return DecoratedBox(
                    key: const Key('global_emergency_alert_frame'),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: opacity),
                        width: width,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(
                            alpha: 0.12 + (_controller.value * 0.15),
                          ),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
