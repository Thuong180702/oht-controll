import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.enabled = true,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.pressedOpacity = 0.82,
    this.pressedScale = 0.97,
    this.cursor,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final double pressedOpacity;
  final double pressedScale;
  final MouseCursor? cursor;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  int? _activePointer;

  bool get _enabled =>
      widget.enabled &&
      (widget.onTap != null ||
          widget.onPressStart != null ||
          widget.onPressEnd != null);

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _setPressed(true);
    HapticFeedback.lightImpact();
    widget.onPressStart?.call();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_enabled || _activePointer != event.pointer) return;
    _activePointer = null;
    _setPressed(false);
    widget.onPressEnd?.call();
    widget.onTap?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_enabled || _activePointer != event.pointer) return;
    _activePointer = null;
    _setPressed(false);
    widget.onPressEnd?.call();
  }

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _pressed) {
      _activePointer = null;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      cursor:
          widget.cursor ??
          (_enabled ? SystemMouseCursors.click : SystemMouseCursors.basic),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _enabled ? _handlePointerDown : null,
        onPointerUp: _enabled ? _handlePointerUp : null,
        onPointerCancel: _enabled ? _handlePointerCancel : null,
        child: child,
      ),
    );
  }
}
