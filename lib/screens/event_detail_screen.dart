// Детальная карточка мероприятия — ТЗ: обложка, название, дата/время, описание, формат, цена, «Записаться»
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart' show formatDateTimeRu;
import '../data/models/api_event.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_cover_image.dart';
import '../widgets/event_photo_report_gallery.dart';
import '../widgets/event_signup_sheet.dart';
import '../widgets/error_view.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/path_cta.dart';
import '../widgets/piligrim_toast.dart';
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
                leadingWidth: 80,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: PiligrimTap(
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
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
                    if (event.maxPlaces > 0) ...[
                      const SizedBox(height: 12),
                      _MetaChip(
                        label: 'Места: ${event.occupiedPlaces} / ${event.maxPlaces}',
                      ),
                    ],
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
                          if (provider.isLoadingPhotoReport &&
                              provider.photoReportError == null) {
                            return const _PhotoReportSkeleton();
                          }
                          if (provider.photoReportError != null) {
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
                                PiligrimInlineError(
                                  message: provider.photoReportError!,
                                  onRetry: () => provider.loadPhotoReport(
                                    event.id,
                                  ),
                                ),
                              ],
                            );
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
                                isAdmin: context.watch<AuthProvider>().isAdmin,
                                onDeletePhoto: (photo) async {
                                  try {
                                    await context
                                        .read<EventsProvider>()
                                        .deletePhotoFromReport(
                                          event.id,
                                          photo.id,
                                        );
                                  } catch (_) {
                                    if (context.mounted) {
                                      PiligrimToast.show(
                                        context,
                                        'Не удалось удалить фото',
                                        type: PiligrimToastType.error,
                                      );
                                    }
                                  }
                                },
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
          if (!event.isPast)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CtaOverlay(
                event: event,
                onTap: () async {
                  if (!await guardAuth(context)) return;
                  if (!context.mounted) return;
                  await showEventSignupSheet(context, event: event);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CtaOverlay extends StatelessWidget {
  const _CtaOverlay({required this.event, required this.onTap});
  final ApiEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFull = event.maxPlaces > 0 &&
        event.occupiedPlaces >= event.maxPlaces;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PiligrimColors.earth.withValues(alpha: 0.0),
            PiligrimColors.earth.withValues(alpha: 0.88),
            PiligrimColors.earth,
          ],
          stops: const [0.0, 0.28, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: PathCta(
            label: isFull ? 'МЕСТ НЕТ' : 'ЗАПИСАТЬСЯ',
            onTap: isFull ? null : onTap,
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
