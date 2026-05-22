// Превью ближайшего мероприятия на главном экране — данные из EventsProvider.upcoming
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/models/api_event.dart';
import '../providers/events_provider.dart';
import 'piligrim_tap.dart';

const _monthsShort = [
  'ЯНВ', 'ФЕВ', 'МАР', 'АПР', 'МАЯ', 'ИЮН',
  'ИЮЛ', 'АВГ', 'СЕН', 'ОКТ', 'НОЯ', 'ДЕК',
];

String _dateLabel(DateTime dt) =>
    '${dt.day} ${_monthsShort[dt.month - 1]}';

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class HomeEventBlock extends StatelessWidget {
  const HomeEventBlock({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final event = provider.upcoming.isNotEmpty ? provider.upcoming.first : null;
    if (event == null) return const SizedBox.shrink();

    return _EventCard(event: event, onNavigate: onNavigate);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onNavigate});
  final ApiEvent event;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final formatLabel = event.format == ApiEventFormat.closed
        ? 'Закрытое мероприятие'
        : event.priceFrom != null
            ? 'от ${event.priceFrom} ₸'
            : 'Вход свободный';

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

          // Карточка
          PiligrimTap(
            borderRadius: BorderRadius.circular(PiligrimRadius.card),
            onTap: () => onNavigate?.call(3),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PiligrimRadius.card),
                color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
                border: Border.all(
                  color: PiligrimColors.sky.withValues(alpha: 0.08),
                  width: 0.75,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PiligrimColors.steppe.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Картинка
                  if (event.coverUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(PiligrimRadius.card),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: event.coverUrl!,
                        width: double.infinity,
                        height: 133,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 133,
                          color: PiligrimColors.earthDeep,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 133,
                          color: PiligrimColors.earthDeep,
                        ),
                      ),
                    )
                  else
                    // Плейсхолдер если нет обложки
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(PiligrimRadius.card),
                      ),
                      child: Container(
                        height: 107,
                        width: double.infinity,
                        color: PiligrimColors.earthDeep,
                        child: Center(
                          child: Text(
                            'PILIGRIM',
                            style: PiligrimTextStyles.caption.copyWith(
                              color: PiligrimColors.sky.withValues(alpha: 0.15),
                              fontSize: 22,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Текстовый блок
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dateLabel(event.startsAt)} · ${_timeLabel(event.startsAt)}',
                          style: PiligrimTextStyles.caption.copyWith(
                            color: PiligrimColors.steppe.withValues(alpha: 0.95),
                            letterSpacing: 1.8,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.title,
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 16,
                            color: PiligrimColors.sky,
                            height: 1.25,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.sky.withValues(alpha: 0.62),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          formatLabel,
                          style: PiligrimTextStyles.caption.copyWith(
                            color: PiligrimColors.water.withValues(alpha: 0.70),
                            fontSize: 10,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(delay: 100.ms, duration: 700.ms, curve: Curves.easeOut),
    );
  }
}
