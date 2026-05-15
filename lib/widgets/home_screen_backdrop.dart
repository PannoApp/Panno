// Кинематографичный фон главной — триптих 21·12·13 + градиенты бренда
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/ambient_preset.dart';
import '../core/theme.dart';
import 'piligrim_triptych_interior_backdrop.dart';

/// Слой под EthnoAmbientBackground: анимированные интерьеры, виньетка, параллакс.
class HomeScreenBackdrop extends StatefulWidget {
  const HomeScreenBackdrop({
    super.key,
    required this.scrollOffset,
    required this.tiltX,
    required this.tiltY,
    required this.preset,
  });

  final double scrollOffset;
  final double tiltX;
  final double tiltY;
  final AppAmbientPreset preset;

  @override
  State<HomeScreenBackdrop> createState() => _HomeScreenBackdropState();
}

class _HomeScreenBackdropState extends State<HomeScreenBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  double _emberHint() {
    return switch (widget.preset) {
      AppAmbientPreset.calm => 0.85,
      AppAmbientPreset.ember => 1.0,
      AppAmbientPreset.mystic => 0.95,
    };
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.scrollOffset * 0.04 + widget.tiltX * 10;
    final py = widget.scrollOffset * 0.02 + widget.tiltY * 10;
    final em = _emberHint();

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: PiligrimColors.earth),

        Positioned.fill(
          child: PiligrimTriptychInteriorBackdrop(
            opacityScale: 0.35,
            parallax: Offset(-px * 0.38, -py * 0.26),
            cycleDuration: const Duration(seconds: 60),
          ),
        ),

        AnimatedBuilder(
          animation: _breathe,
          builder: (_, __) {
            final t = _breathe.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.1 + math.sin(t * math.pi * 2) * 0.06,
                          -0.25,
                        ),
                        radius: 1.3,
                        colors: [
                          PiligrimColors.steppe.withValues(alpha: 0.06 * em),
                          PiligrimColors.earth.withValues(alpha: 0.4),
                          PiligrimColors.earth,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 0.75, 1.0],
                        colors: [
                          PiligrimColors.clear,
                          PiligrimColors.earth.withValues(alpha: 0.5),
                          PiligrimColors.earth.withValues(alpha: 0.75),
                          PiligrimColors.earth,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
