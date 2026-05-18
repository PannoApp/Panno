// Строка статуса внизу главного экрана — «Открыто/Закрыто» с пульсирующей точкой
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/home_data.dart';

class HomeStatusLine extends StatefulWidget {
  const HomeStatusLine({
    super.key,
    this.isOpen,
    this.hoursLabel,
  });

  final bool? isOpen;
  final String? hoursLabel;

  @override
  State<HomeStatusLine> createState() => _HomeStatusLineState();
}

class _HomeStatusLineState extends State<HomeStatusLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  bool get _open => widget.isOpen ?? kRestaurantInfo.isOpen;

  String get _hours =>
      widget.hoursLabel ??
      '${kRestaurantInfo.scheduleLabel} · ${kRestaurantInfo.hoursLabel}';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_open) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HomeStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      if (_open) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
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
          Flexible(
            child: Text(
              _hours,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms);
  }
}
