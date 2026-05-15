// Строка статуса внизу главного экрана — «Открыто/Закрыто» с пульсирующей точкой
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/home_data.dart';

class HomeStatusLine extends StatefulWidget {
  const HomeStatusLine({super.key});

  @override
  State<HomeStatusLine> createState() => _HomeStatusLineState();
}

class _HomeStatusLineState extends State<HomeStatusLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (kRestaurantInfo.isOpen) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const info = kRestaurantInfo;
    final open = info.isOpen;
    final dotColor =
        open ? PiligrimColors.water : PiligrimColors.sky.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: open
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(
                            alpha: 0.3 + _pulseCtrl.value * 0.3,
                          ),
                          blurRadius: 4 + _pulseCtrl.value * 6,
                          spreadRadius: _pulseCtrl.value * 1.5,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            open ? 'Открыто' : 'Закрыто',
            style: PiligrimTextStyles.body.copyWith(
              color: open
                  ? PiligrimColors.water.withValues(alpha: 0.7)
                  : PiligrimColors.sky.withValues(alpha: 0.3),
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${info.scheduleLabel} · ${info.hoursLabel}',
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms);
  }
}
