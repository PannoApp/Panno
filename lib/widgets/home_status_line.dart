// Строка статуса на главном экране — «Открыто/Закрыто» с пульсирующей точкой
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
    // BUG-C фикс: закрытый статус использовал alpha 0.55/0.65 — почти невидимо
    // на earthSurface. Поднимаем до 0.82/0.88 чтобы читалось нормально.
    final dotColor = open
        ? PiligrimColors.water
        : PiligrimColors.fruit.withValues(alpha: 0.82);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Тонкая steppe-hairline — разделитель перед строкой статуса
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 0.5,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PiligrimColors.steppe.withValues(alpha: 0.0),
                  PiligrimColors.steppe.withValues(alpha: 0.18),
                  PiligrimColors.steppe.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                open ? 'ОТКРЫТО' : 'ЗАКРЫТО',
                style: PiligrimTextStyles.caption.copyWith(
                  color: open
                      ? PiligrimColors.water.withValues(alpha: 0.78)
                      : PiligrimColors.fruit.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 9,
                color: PiligrimColors.steppe.withValues(alpha: 0.22),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  _hours,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.sky.withValues(
                      alpha: open ? 0.40 : 0.55,
                    ),
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms);
  }
}
