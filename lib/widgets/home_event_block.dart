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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 0.5,
            color: PiligrimColors.sky.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'БЛИЖАЙШЕЕ СОБЫТИЕ',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.5),
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
                    color: PiligrimColors.water.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${event.dateLabel} · ${event.timeLabel}',
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.steppe.withValues(alpha: 0.7),
              letterSpacing: 2.0,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          PiligrimTap(
            onTap: () => onNavigate?.call(3),
            child: Text(
              event.title,
              style: PiligrimTextStyles.heading.copyWith(
                fontSize: 22,
                color: PiligrimColors.sky,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event.description,
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tagsText,
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.water.withValues(alpha: 0.6),
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(delay: 100.ms, duration: 700.ms, curve: Curves.easeOut),
    );
  }
}
