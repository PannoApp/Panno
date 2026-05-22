// Превью ближайшего мероприятия на главном экране — EventsProvider + cover image.
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
          Row(
            children: [
              Text(
                'БЛИЖАЙШЕЕ СОБЫТИЕ',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.steppe.withValues(alpha: 0.78),
                  letterSpacing: 2.5,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w300,
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

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onNavigate});

  final ApiEvent event;
  final ValueChanged<int>? onNavigate;

  static const _months = [
    'ЯНВАРЯ', 'ФЕВРАЛЯ', 'МАРТА', 'АПРЕЛЯ', 'МАЯ', 'ИЮНЯ',
    'ИЮЛЯ', 'АВГУСТА', 'СЕНТЯБРЯ', 'ОКТЯБРЯ', 'НОЯБРЯ', 'ДЕКАБРЯ',
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PiligrimRadius.card),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
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
                  AspectRatio(
                    aspectRatio: 2.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasCover)
                          CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const _CoverPlaceholder(),
                            errorWidget: (_, __, ___) =>
                                const _CoverPlaceholder(),
                          )
                        else
                          const _CoverPlaceholder(),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x00000000),
                                Color(0x60211D1A),
                                Color(0xEB211D1A),
                              ],
                              stops: [0.0, 0.45, 0.75, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: PiligrimColors.earthDeep
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PiligrimColors.water
                                    .withValues(alpha: 0.30),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              dateLabel,
                              style: PiligrimTextStyles.caption.copyWith(
                                color: PiligrimColors.steppe
                                    .withValues(alpha: 0.95),
                                fontSize: 9,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 21,
                            color: PiligrimColors.sky,
                            height: 1.28,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.sky.withValues(alpha: 0.68),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatLabel,
                          style: PiligrimTextStyles.caption.copyWith(
                            color: PiligrimColors.water.withValues(alpha: 0.80),
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PiligrimColors.earthDeep,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/spiral.svg',
          width: 36,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.15),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _EventBlockEmpty extends StatelessWidget {
  const _EventBlockEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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

class _EventLoadingSkeleton extends StatelessWidget {
  const _EventLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PiligrimRadius.card),
        color: PiligrimColors.earthDeep.withValues(alpha: 0.40),
        border: Border.all(
          color: PiligrimColors.sky.withValues(alpha: 0.06),
          width: 0.75,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(PiligrimRadius.card),
              ),
              child: ColoredBox(
                color: PiligrimColors.earthWarm.withValues(alpha: 0.55),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 180, height: 20),
                SizedBox(height: 10),
                _SkeletonLine(width: double.infinity, height: 12),
                SizedBox(height: 6),
                _SkeletonLine(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 900.ms)
        .then()
        .fadeOut(duration: 900.ms);
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PiligrimColors.sky.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
