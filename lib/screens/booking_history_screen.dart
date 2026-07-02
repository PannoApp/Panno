import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/api_booking.dart';
import '../providers/booking_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadHistory();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<BookingProvider>().loadHistory();
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
          Consumer<BookingProvider>(
            builder: (context, provider, _) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                color: PiligrimColors.water,
                backgroundColor: PiligrimColors.earthDeep,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: top + 16),
                    ),
                    // Заголовок
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
                                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Назад',
                                      style: PiligrimTextStyles.caption.copyWith(
                                        color: PiligrimColors.sky.withValues(alpha: 0.45),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'МОИ БРОНИРОВАНИЯ',
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

                    if (provider.isLoadingHistory && provider.history.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: PiligrimLoader(),
                        ),
                      )
                    else if (provider.historyError != null && provider.history.isEmpty)
                      SliverErrorView(
                        message: provider.historyError!,
                        onRetry: () => context.read<BookingProvider>().retryHistory(),
                      )
                    else if (provider.history.isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BookingCard(
                                booking: provider.history[index],
                                index: index,
                              ),
                            ),
                            childCount: provider.history.length,
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
// Карточка одного бронирования
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.index});

  final ApiBooking booking;
  final int index;

  @override
  Widget build(BuildContext context) {
    final badge = _StatusBadge.forStatus(booking.status);
    final time = _trimTime(booking.time);
    final detailLine = [time, _formatHeroesCount(booking.guestsCount)].join('  ·  ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PiligrimColors.earthWarm.withValues(alpha: 0.16),
            PiligrimColors.earth.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.14),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.steppe.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка: дата + статус
            Row(
              children: [
                Text(
                  _formatDate(booking.date),
                  style: PiligrimTextStyles.heading.copyWith(
                    fontSize: 15,
                    color: PiligrimColors.sky,
                  ),
                ),
                const Spacer(),
                badge,
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 0.5,
              color: PiligrimColors.sky.withValues(alpha: 0.10),
            ),
            const SizedBox(height: 10),
            if (booking.zone != null) ...[
              Text(
                _localizeZone(booking.zone!),
                style: PiligrimTextStyles.heading.copyWith(
                  fontSize: 14,
                  color: PiligrimColors.sky,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              detailLine,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 12,
                color: PiligrimColors.sky.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ),
    ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms);
  }

  String _formatDate(String iso) {
    // Ожидаемый формат с API: «YYYY-MM-DD»
    try {
      final parts = iso.split('-');
      if (parts.length != 3) return iso;
      final months = [
        '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
      ];
      final day = parts[2];
      final month = months[int.parse(parts[1])];
      final year = parts[0];
      return '$day $month $year';
    } catch (_) {
      return iso;
    }
  }

  String _trimTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  String _localizeZone(String zone) {
    switch (zone.toLowerCase()) {
      case 'main':
        return 'Главный зал';
      case 'terrace':
        return 'Терраса';
      case 'private':
        return 'Приват';
      default:
        return zone;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge статуса
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  factory _StatusBadge.forStatus(String status) {
    switch (status) {
      case 'pending':
        return const _StatusBadge(
          label: 'Ожидает',
          color: PiligrimColors.steppe,
        );
      case 'confirmed':
        return const _StatusBadge(
          label: 'Подтверждено',
          color: PiligrimColors.water,
        );
      case 'completed':
        return const _StatusBadge(
          label: 'Завершено',
          color: PiligrimColors.success,
        );
      case 'canceled':
      default:
        return _StatusBadge(
          label: 'Отменено',
          color: PiligrimColors.sky.withValues(alpha: 0.3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 9.5,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Пустое состояние
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
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
            'Путь ещё не начат',
            style: PiligrimTextStyles.heading.copyWith(
              fontSize: 16,
              color: PiligrimColors.sky.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь появятся ваши бронирования',
            style: PiligrimTextStyles.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }
}

String _formatHeroesCount(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return '$count герой';
  } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
    return '$count героя';
  } else {
    return '$count героев';
  }
}

