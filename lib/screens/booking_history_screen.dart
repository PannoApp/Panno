import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/api_booking.dart';
import '../providers/booking_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/piligrim_background.dart';
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
            ),
          ),
          Consumer<BookingProvider>(
            builder: (context, provider, _) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                color: PiligrimColors.water,
                backgroundColor: PiligrimColors.earthDeep,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.of(context).pop(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: SvgPicture.asset(
                                  'assets/images/splash_path (1).svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    PiligrimColors.water.withValues(alpha: 0.7),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'МОИ БРОНИРОВАНИЯ',
                              style: PiligrimTextStyles.heading.copyWith(
                                fontSize: 16,
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
                          child: CircularProgressIndicator(
                            color: PiligrimColors.water,
                            strokeWidth: 2,
                          ),
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

    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.shadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
            const Divider(height: 1, color: PiligrimColors.divider),
            const SizedBox(height: 10),

            // Детали
            _DetailRow(
              icon: 'assets/images/sun.svg',
              text: booking.time,
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: 'assets/images/shaman.svg',
              text: '${booking.guestsCount} гостей',
            ),
            if (booking.zone != null) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: 'assets/images/star_totem (1).svg',
                text: _localizeZone(booking.zone!),
              ),
            ],
          ],
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
// Строка деталей с иконкой
// ─────────────────────────────────────────────────────────────────────────────
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
        Text(
          text,
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 13,
            color: PiligrimColors.sky.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
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
          color: Color(0xFF5A9A6A),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
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

