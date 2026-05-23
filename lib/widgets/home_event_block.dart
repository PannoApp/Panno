// Превью ближайшего мероприятия на главном экране — EventsProvider + cover image.
// Вариант А: афишный постер full-bleed, текст оверлеем, pill «Все события».
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/media_url.dart';
import '../core/theme.dart';
import '../data/models/api_event.dart';
import '../providers/events_provider.dart';
import 'piligrim_tap.dart';

class HomeEventBlock extends StatelessWidget {
  const HomeEventBlock({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final isLoading = provider.isLoadingUpcoming;
    final events = provider.upcoming;
    final event = events.isNotEmpty ? events.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(onNavigate: onNavigate),
          const SizedBox(height: 14),
          if (isLoading && event == null)
            const _EventLoadingSkeleton()
          else if (event == null)
            const _EventBlockEmpty()
          else
            _EventCard(event: event, onNavigate: onNavigate),
        ],
      )
          .animate()
          .fadeIn(delay: 100.ms, duration: 700.ms, curve: Curves.easeOut),
    );
  }
}

// ─── Хедер секции ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Вертикальный акцент-штрих
        Container(
          width: 2,
          height: 11,
          decoration: BoxDecoration(
            color: PiligrimColors.steppe.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'БЛИЖАЙШЕЕ СОБЫТИЕ',
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.steppe.withValues(alpha: 0.85),
            letterSpacing: 2.4,
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        ),
        const Spacer(),
        // Pill «Все события →»
        PiligrimTap(
          onTap: () => onNavigate?.call(3),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PiligrimColors.water.withValues(alpha: 0.38),
                width: 0.75,
              ),
            ),
            child: Text(
              'Все события  →',
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.water,
                fontSize: 10.5,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Карточка-постер full-bleed ──────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onNavigate});

  final ApiEvent event;
  final ValueChanged<int>? onNavigate;

  static const _months = [
    'ЯНВ', 'ФЕВ', 'МАР', 'АПР', 'МАЯ', 'ИЮН',
    'ИЮЛ', 'АВГ', 'СЕН', 'ОКТ', 'НОЯ', 'ДЕК',
  ];

  String _formatDate(DateTime dt) {
    final month = _months[dt.month - 1];
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} $month · $time';
  }

  String get _formatLabel => event.format == ApiEventFormat.closed
      ? 'Закрытое мероприятие'
      : event.priceFrom != null
          ? 'от ${event.priceFrom} ₸'
          : 'Вход свободный';

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(event.startsAt);
    final coverUrl = resolveMediaUrl(event.coverUrl);
    final hasCover = coverUrl.isNotEmpty;

    return PiligrimTap(
      borderRadius: BorderRadius.circular(PiligrimRadius.card),
      onTap: () => onNavigate?.call(3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PiligrimRadius.card),
            // На тёмном фоне shadow не виден — используем цветное свечение (glow)
            boxShadow: [
              BoxShadow(
                color: PiligrimColors.steppe.withValues(alpha: 0.22),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: PiligrimColors.ember.withValues(alpha: 0.10),
                blurRadius: 48,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(PiligrimRadius.card),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Фоновое изображение ──────────────────────────────
                if (hasCover)
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _CoverPlaceholder(),
                    errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                  )
                else
                  const _CoverPlaceholder(),

                // ── 2. Верхний виньеточный слой (тень для читаемости даты)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x88080604),
                          Color(0x00000000),
                          Color(0x00000000),
                        ],
                        stops: [0.0, 0.28, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── 3. Нижний градиент — основа для текста ─────────────
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xBB0E0B09),
                          Color(0xF50E0B09),
                        ],
                        stops: [0.0, 0.38, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── 4. Бейдж даты — верхний правый угол ────────────────
                Positioned(
                  top: 14,
                  right: 14,
                  child: _DateBadge(label: dateLabel),
                ),

                // ── 5. Текстовый оверлей снизу ──────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 22,
                            color: PiligrimColors.sky,
                            height: 1.22,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.bodySmall.copyWith(
                            color: PiligrimColors.sky.withValues(alpha: 0.62),
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 0.5,
                          color: PiligrimColors.sky.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              _formatLabel,
                              style: PiligrimTextStyles.caption.copyWith(
                                color: PiligrimColors.water,
                                fontSize: 11.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    PiligrimColors.water.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Подробнее',
                                style: PiligrimTextStyles.micro.copyWith(
                                  color: PiligrimColors.water
                                      .withValues(alpha: 0.85),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Бейдж даты ──────────────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.30),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: PiligrimTextStyles.micro.copyWith(
          color: PiligrimColors.steppe.withValues(alpha: 0.95),
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

// ─── Заглушка без изображения ────────────────────────────────────────────────

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Атмосферный тёплый градиент — имитация свечения очага
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, 0.2),
              radius: 1.0,
              colors: [
                Color(0xFF2B1E14), // тёплый уголь
                Color(0xFF1A1108), // глубокий тёмно-коричневый
                Color(0xFF0E0B08), // почти чёрный
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Горизонтальная тёплая полоса по центру — намёк на горизонт / степь
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  PiligrimColors.ember.withValues(alpha: 0.06),
                  PiligrimColors.steppe.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // Центральный символ
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/spiral.svg',
                width: 56,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.steppe.withValues(alpha: 0.28),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'МЕРОПРИЯТИЕ',
                style: PiligrimTextStyles.micro.copyWith(
                  color: PiligrimColors.steppe.withValues(alpha: 0.30),
                  letterSpacing: 3.0,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Пустое состояние ────────────────────────────────────────────────────────

class _EventBlockEmpty extends StatelessWidget {
  const _EventBlockEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PiligrimRadius.card),
        color: PiligrimColors.earthDeep.withValues(alpha: 0.40),
        border: Border.all(
          color: PiligrimColors.sky.withValues(alpha: 0.06),
          width: 0.75,
        ),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 28,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.18),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Новые маршруты скоро появятся',
            textAlign: TextAlign.center,
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.42),
              fontSize: 11.5,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Скелетон загрузки ───────────────────────────────────────────────────────

class _EventLoadingSkeleton extends StatelessWidget {
  const _EventLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PiligrimRadius.card),
      child: AspectRatio(
        aspectRatio: 1.25,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.2),
                radius: 1.0,
                colors: [
                  Color(0xFF2B1E14),
                  Color(0xFF1A1108),
                  Color(0xFF0E0B08),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xBB0E0B09),
                      Color(0xF50E0B09),
                    ],
                    stops: [0.0, 0.38, 0.68, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 90,
                height: 26,
                decoration: BoxDecoration(
                  color: PiligrimColors.sky.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 18,
              right: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonLine(
                      width: 200, height: 20, opacity: 0.10),
                  const SizedBox(height: 8),
                  _SkeletonLine(
                      width: double.infinity, height: 12, opacity: 0.07),
                  const SizedBox(height: 5),
                  _SkeletonLine(width: 140, height: 12, opacity: 0.07),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 900.ms)
        .then()
        .fadeOut(duration: 900.ms);
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine(
      {required this.width, required this.height, this.opacity = 0.08});
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PiligrimColors.sky.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
