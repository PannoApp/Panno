// Детальная карточка мероприятия — ТЗ: обложка, название, дата/время, описание, формат, цена, «Записаться»
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart' show formatDateTimeRu;
import '../data/models/api_event.dart';
import '../widgets/event_cover_image.dart';
import '../widgets/event_signup_sheet.dart';
import '../widgets/piligrim_background.dart';
import '../core/auth_guard.dart';
import '../widgets/piligrim_tap.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.coverFallbackIndex = 0,
  });

  final ApiEvent event;
  final int coverFallbackIndex;

  String _priceLine() {
    if (event.priceFrom == null) {
      return 'Стоимость уточняется при записи';
    }
    final formatted = '${event.priceFrom}'.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return 'Вход: от $formatted ₸';
  }

  @override
  Widget build(BuildContext context) {
    final fallback = event.fallbackCoverAsset(coverFallbackIndex);

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
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: PiligrimColors.earthDeep,
                leadingWidth: 108,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: PiligrimTap(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/images/chevron_left_totem.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              PiligrimColors.water,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Назад',
                            maxLines: 1,
                            softWrap: false,
                            style: PiligrimTextStyles.body.copyWith(
                              fontSize: 15,
                              color: PiligrimColors.sky,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      EventCoverImage(
                        imageUrl: event.coverUrl,
                        fallbackAsset: fallback,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PiligrimColors.earthDeep.withValues(alpha: 0.1),
                              PiligrimColors.earthDeep.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      event.title,
                      style: PiligrimTextStyles.title.copyWith(
                        color: PiligrimColors.sky,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatDateTimeRu(event.startsAt),
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.water,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MetaChip(
                      label: '${event.formatLabelRu} мероприятие',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _priceLine(),
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.steppe.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      event.description,
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.92),
                        height: 1.65,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: event.isPast
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  height: 52,
                  child: PiligrimTap(
                    onTap: () async {
                      if (!await guardAuth(context)) return;
                      if (!context.mounted) return;
                      await showEventSignupSheet(
                        context,
                        eventId: event.id,
                        eventTitle: event.title,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: PiligrimColors.water,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'ЗАПИСАТЬСЯ',
                          style: PiligrimTextStyles.button.copyWith(
                            fontSize: 15,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PiligrimColors.earth,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PiligrimColors.divider),
        ),
        child: Text(
          label,
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.9),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
