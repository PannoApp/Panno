import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Премиальный отклик нажатия PILIGRIM — замена InkWell/WaterInkWell.
///
/// При нажатии: плавный scale 0.97 + лёгкое затемнение + HapticFeedback.
/// Никаких кругов на воде, никакого Material ripple.
class PiligrimTap extends StatefulWidget {
  const PiligrimTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.scaleDown = 0.97,
    this.pressedOpacity = 0.82,
    this.haptic = true,
    this.pressDuration = const Duration(milliseconds: 100),
    this.releaseDuration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double scaleDown;
  final double pressedOpacity;
  final bool haptic;
  final Duration pressDuration;
  final Duration releaseDuration;

  @override
  State<PiligrimTap> createState() => _PiligrimTapState();
}

class _PiligrimTapState extends State<PiligrimTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();

  void _onTapUp(TapUpDetails _) => _ctrl.reverse();

  void _onTapCancel() => _ctrl.reverse();

  void _onTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_ctrl.value);
          final scale = 1.0 - (1.0 - widget.scaleDown) * t;
          final opacity = 1.0 - (1.0 - widget.pressedOpacity) * t;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
