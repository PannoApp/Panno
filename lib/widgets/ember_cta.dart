// EmberCta — кнопка с огненным мотивом согласно ТЗ:
// «тёплое свечение, мягкие переходы оранжевого по краю активных кнопок,
//  едва заметная анимация мерцания на ключевых акцентах»
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Основная CTA-кнопка с медным свечением и мерцанием
class EmberCta extends StatefulWidget {
  const EmberCta({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onTap,
    this.small = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;
  final bool small;

  @override
  State<EmberCta> createState() => _EmberCtaState();
}

class _EmberCtaState extends State<EmberCta> with TickerProviderStateMixin {
  late AnimationController _flickerCtrl;
  AnimationController? _idleCtrl;

  @override
  void initState() {
    super.initState();
    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    if (!widget.small) {
      _idleCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 11),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flickerCtrl.dispose();
    _idleCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paddedRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 18),
      child: Row(
        children: [
          SvgPicture.asset(
            widget.iconAsset,
            width: widget.small ? 17 : 20,
            height: widget.small ? 17 : 20,
            colorFilter: const ColorFilter.mode(
              PiligrimColors.sky,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: widget.small ? 10 : 14),
          Text(
            widget.label,
            style: PiligrimTextStyles.button.copyWith(
              color: PiligrimColors.sky,
              fontSize: widget.small ? 12.5 : 13.5,
              letterSpacing: 0.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '→',
            style: PiligrimTextStyles.caption.copyWith(
              fontSize: widget.small ? 11 : 12,
              color: PiligrimColors.sky.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );

    final tapChild = PiligrimTap(
      borderRadius: BorderRadius.circular(8),
      onTap: widget.onTap,
      scaleDown: 0.965,
      releaseDuration: const Duration(milliseconds: 320),
      child: AnimatedBuilder(
        animation: _flickerCtrl,
        builder: (_, child) {
          final t = _flickerCtrl.value;
          final flicker = 0.85 +
              0.08 * math.sin(t * math.pi * 3.7) +
              0.05 * math.sin(t * math.pi * 7.2) +
              0.02 * math.sin(t * math.pi * 13.1);

          final glowRadius = (6 + flicker * 3).clamp(6.0, 11.0);
          final glowOpacity = (0.10 + flicker * 0.04).clamp(0.07, 0.16);

          return Container(
            height: widget.small ? 44 : 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PiligrimColors.steppe,
                  PiligrimColors.emberDeep,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: PiligrimColors.shadow.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: PiligrimColors.ember.withValues(alpha: glowOpacity),
                  blurRadius: glowRadius,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        child: paddedRow,
      ),
    );

    final idle = _idleCtrl;
    if (idle != null) {
      return AnimatedBuilder(
        animation: idle,
        builder: (_, child) {
          final breathe =
              1.0 + 0.003 * math.sin(idle.value * math.pi * 2);
          return Transform.scale(
            scale: breathe,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: tapChild,
      );
    }
    return tapChild;
  }
}

/// Декоративный виджет — едва заметное мерцание огня у акцентного элемента
/// Оборачивает любой виджет тёплым пульсирующим свечением
class EmberGlow extends StatefulWidget {
  const EmberGlow({
    super.key,
    required this.child,
    this.radius = 12.0,
    this.intensity = 1.0,
  });

  final Widget child;
  final double radius;
  final double intensity;

  @override
  State<EmberGlow> createState() => _EmberGlowState();
}

class _EmberGlowState extends State<EmberGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        final pulse = 0.75 +
            0.15 * math.sin(t * math.pi * 2.3) +
            0.1 * math.sin(t * math.pi * 5.7);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: PiligrimColors.ember.withValues(
                  alpha: (0.15 + pulse * 0.1 * widget.intensity)
                      .clamp(0.0, 0.35),
                ),
                blurRadius: (8 + pulse * 8 * widget.intensity)
                    .clamp(4.0, 20.0),
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
