// Детальная карточка мероприятия — ТЗ: обложка, название, дата/время, описание, формат, цена, «Записаться»
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart' show formatDateTimeRu;
import '../data/models/api_event.dart';
import '../providers/events_provider.dart';
import '../widgets/event_cover_image.dart';
import '../widgets/event_photo_report_gallery.dart';
import '../widgets/event_signup_sheet.dart';
import '../widgets/piligrim_background.dart';
import '../core/auth_guard.dart';
import '../widgets/piligrim_tap.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.coverFallbackIndex = 0,
  });

  final ApiEvent event;
  final int coverFallbackIndex;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.event.isPast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<EventsProvider>().loadPhotoReport(widget.event.id);
      });
    }
  }

  String _priceLine() {
    if (widget.event.priceFrom == null) {
      return 'Стоимость уточняется при записи';
    }
    final formatted = '${widget.event.priceFrom}'.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
    return 'Вход: от $formatted ₸';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final fallback = event.fallbackCoverAsset(widget.coverFallbackIndex);

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
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: PiligrimColors.water,
                            borderRadius: BorderRadius.circular(2.5),
                            boxShadow: [
                              BoxShadow(
                                color: PiligrimColors.water
                                    .withValues(alpha: 0.55),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDateTimeRu(event.startsAt),
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.water,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MetaChip(
                      label: '${event.formatLabelRu} мероприятие',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                PiligrimColors.steppe.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _priceLine(),
                            style: PiligrimTextStyles.caption.copyWith(
                              color: PiligrimColors.steppe
                                  .withValues(alpha: 0.85),
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Тонкая steppe→transparent hairline — единый штрих с section headers
                    Container(
                      height: 1,
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PiligrimColors.steppe.withValues(alpha: 0.45),
                            PiligrimColors.steppe.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      event.description,
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.92),
                        height: 1.65,
                      ),
                    ),
                    if (event.isPast) ...[
                      const SizedBox(height: 32),
                      Consumer<EventsProvider>(
                        builder: (_, provider, __) {
                          if (provider.isLoadingPhotoReport) {
                            return const _PhotoReportSkeleton();
                          }
                          if (provider.photoReport.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Фотоотчёт',
                                style: PiligrimTextStyles.title.copyWith(
                                  color: PiligrimColors.sky,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              EventPhotoReportGallery(
                                photos: provider.photoReport,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
                child: _EventSignupCta(
                  onTap: () async {
                    if (!await guardAuth(context)) return;
                    if (!context.mounted) return;
                    await showEventSignupSheet(
                      context,
                      eventId: event.id,
                      eventTitle: event.title,
                    );
                  },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: PiligrimColors.steppe.withValues(alpha: 0.55),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: PiligrimColors.steppe.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2.5),
                boxShadow: [
                  BoxShadow(
                    color: PiligrimColors.steppe.withValues(alpha: 0.4),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.92),
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Главный CTA «ЗАПИСАТЬСЯ» — water gradient + rim-highlight + water-tinted shadow.
// По мотиву EmberCta, но в холодном water-цвете (сервисное действие, не финальное).
class _EventSignupCta extends StatelessWidget {
  const _EventSignupCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: PiligrimTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        scaleDown: 0.965,
        releaseDuration: const Duration(milliseconds: 320),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PiligrimColors.water,
                PiligrimColors.waterMuted,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: PiligrimColors.shadow.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: PiligrimColors.water.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  'ЗАПИСАТЬСЯ',
                  style: PiligrimTextStyles.button.copyWith(
                    fontSize: 14.5,
                    letterSpacing: 1.6,
                    color: PiligrimColors.sky,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: Container(
                  height: 0.75,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    gradient: LinearGradient(
                      colors: [
                        PiligrimColors.sky.withValues(alpha: 0.0),
                        PiligrimColors.sky.withValues(alpha: 0.22),
                        PiligrimColors.sky.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoReportSkeleton extends StatelessWidget {
  const _PhotoReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          height: 20,
          decoration: BoxDecoration(
            color: PiligrimColors.earthDeep,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            height: 220,
            child: ColoredBox(color: PiligrimColors.earthDeep),
          ),
        ),
      ],
    );
  }
}
