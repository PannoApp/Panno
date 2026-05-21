// Превью ближайшего мероприятия на главном экране (дата, название, описание, теги)
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import 'piligrim_tap.dart';

class HomeEventBlock extends StatelessWidget {
  const HomeEventBlock({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    const event = kNearestEvent;
    final tagsText = event.tags.map((t) => t.label).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка секции
          Row(
            children: [
              Text(
                'БЛИЖАЙШЕЕ СОБЫТИЕ',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.48),
                  letterSpacing: 2.4,
                  fontSize: 9,
                ),
              ),
              const Spacer(),
              PiligrimTap(
                onTap: () => onNavigate?.call(3),
                child: Text(
                  'Все события →',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.water.withValues(alpha: 0.80),
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Карточка события
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PiligrimRadius.card),
              color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
              border: Border.all(
                color: PiligrimColors.sky.withValues(alpha: 0.08),
                width: 0.75,
              ),
              // Тонкий accent-border слева — «закладка» события
              boxShadow: [
                BoxShadow(
                  color: PiligrimColors.steppe.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Left accent line
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: -16,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(PiligrimRadius.card),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          PiligrimColors.steppe.withValues(alpha: 0.0),
                          PiligrimColors.steppe.withValues(alpha: 0.55),
                          PiligrimColors.steppe.withValues(alpha: 0.55),
                          PiligrimColors.steppe.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Дата — яркий steppe акцент
                    Text(
                      '${event.dateLabel} · ${event.timeLabel}',
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.steppe.withValues(alpha: 0.95),
                        letterSpacing: 2.0,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Заголовок события
                    PiligrimTap(
                      onTap: () => onNavigate?.call(3),
                      child: Text(
                        event.title,
                        style: PiligrimTextStyles.heading.copyWith(
                          fontSize: 21,
                          color: PiligrimColors.sky,
                          height: 1.28,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Описание
                    Text(
                      event.description,
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Теги
                    Text(
                      tagsText,
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.water.withValues(alpha: 0.75),
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(delay: 100.ms, duration: 700.ms, curve: Curves.easeOut),
    );
  }
}
