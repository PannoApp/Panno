import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import '../data/models/api_event_reservation.dart';
import '../data/repositories/event_reservation_repository.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

class EventReservationHistoryScreen extends StatefulWidget {
  const EventReservationHistoryScreen({super.key});

  @override
  State<EventReservationHistoryScreen> createState() =>
      _EventReservationHistoryScreenState();
}

class _EventReservationHistoryScreenState
    extends State<EventReservationHistoryScreen> {
  final _repo = EventReservationRepository();
  late Future<List<ApiEventReservation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyReservations();
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchMyReservations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        children: [
          const Positioned.fill(
            child: PiligrimBackground(
              textureOpacity: 0.45,
              vignetteIntensity: 0.25,
              cinematic: true,
            ),
          ),
          FutureBuilder<List<ApiEventReservation>>(
            future: _future,
            builder: (context, snapshot) {
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                color: PiligrimColors.water,
                backgroundColor: PiligrimColors.earthDeep,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: top + 16)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Row(
                          children: [
                            PiligrimTap(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 12,
                                      color: PiligrimColors.sky
                                          .withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Назад',
                                      style: PiligrimTextStyles.caption
                                          .copyWith(
                                        color: PiligrimColors.sky
                                            .withValues(alpha: 0.45),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'МОИ МЕРОПРИЯТИЯ',
                              style: PiligrimTextStyles.heading.copyWith(
                                fontSize: 17,
                                color: PiligrimColors.sky,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(
                        child: Center(child: PiligrimLoader()),
                      )
                    else if (snapshot.hasError)
                      SliverFillRemaining(
                        child: _ErrorState(onRetry: _reload),
                      )
                    else if (snapshot.data?.isEmpty ?? true)
                      const SliverFillRemaining(
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ReservationCard(
                                reservation: snapshot.data![index],
                                index: index,
                              ),
                            ),
                            childCount: snapshot.data!.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Карточка одной записи на мероприятие
// ─────────────────────────────────────────────────────────────────────────────
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.index,
  });

  final ApiEventReservation reservation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final event = reservation.eventDetails;
    final dateStr = _formatDate(event.startsAt);
    final timeStr = _formatTime(event.startsAt);

    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
        boxShadow: PiligrimShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 15,
                      color: PiligrimColors.sky,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _FormatBadge(isPast: event.isPast),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 0.5,
              color: PiligrimColors.sky.withValues(alpha: 0.10),
            ),
            const SizedBox(height: 10),
            _DetailRow(
              icon: 'assets/images/sun.svg',
              text: '$dateStr · $timeStr',
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: 'assets/images/shaman.svg',
              text: _formatGuestsCount(reservation.guestsCount),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms);
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatGuestsCount(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count герой';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$count героя';
    }
    return '$count героев';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          icon,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(
            PiligrimColors.water.withValues(alpha: 0.5),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 13,
              color: PiligrimColors.sky.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.isPast});

  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color = isPast
        ? PiligrimColors.sky.withValues(alpha: 0.3)
        : PiligrimColors.water;
    final label = isPast ? 'ЗАВЕРШЕНО' : 'ПРЕДСТОИТ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: PiligrimTextStyles.caption.copyWith(
          fontSize: 9.5,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Пустое состояние
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/moon_totem (1).svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              PiligrimColors.water.withValues(alpha: 0.15),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Мероприятий пока нет',
            style: PiligrimTextStyles.heading.copyWith(
              fontSize: 16,
              color: PiligrimColors.sky.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь появятся ваши записи на события',
            style: PiligrimTextStyles.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Состояние ошибки
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Не удалось загрузить данные',
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          PiligrimTap(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Повторить',
                style: PiligrimTextStyles.button.copyWith(
                  color: PiligrimColors.steppe,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
