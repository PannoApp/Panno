import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// Journey / Path CTA — кнопка «Забронировать стол» на главном экране.
///
/// Вертикальные маркеры тихо «дышат» в покое — подсознательный сигнал
/// кликабельности. При нажатии: текст → steppe, маркеры ярче и выше, scale-down.
class PathCta extends StatefulWidget {
  const PathCta({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<PathCta> createState() => _PathCtaState();
}

class _PathCtaState extends State<PathCta> with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _idleCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 85),
      reverseDuration: const Duration(milliseconds: 310),
    );
    _pressAnim = CurvedAnimation(
      parent: _pressCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // Медленный пульс маркеров в покое — 0.42 → 0.64 → 0.42
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _pressCtrl.forward();
  void _up(TapUpDetails _) => _pressCtrl.reverse();
  void _cancel() => _pressCtrl.reverse();

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap != null ? _tap : null,
      child: SizedBox(
        height: 52,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressAnim, _idleCtrl]),
          builder: (_, __) {
            final p = _pressAnim.value;
            final idle = _idleCtrl.value;

            // Маркеры дышат в покое; нажатие перебивает idle
            final idleOpacity = 0.42 + idle * 0.22;
            final markerOpacity = p > 0
                ? (0.50 + p * 0.40)
                : idleOpacity;
            final markerH = 18.0 + p * 8.0;

            final textColor = Color.lerp(
              PiligrimColors.nomadCream,
              PiligrimColors.steppe,
              p,
            )!;
            final scale = 1.0 - p * 0.026;

            return Transform.scale(
              scale: scale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Marker(height: markerH, opacity: markerOpacity),
                  const SizedBox(width: 22),
                  Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PiligrimFonts.museoSans,
                      fontWeight: FontWeight.w300,
                      fontSize: 13.5,
                      height: 1.0,
                      letterSpacing: 3.4,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 22),
                  _Marker(height: markerH, opacity: markerOpacity),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.height, required this.opacity});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: height,
      child: ColoredBox(
        color: PiligrimColors.steppe.withValues(alpha: opacity),
      ),
    );
  }
}
