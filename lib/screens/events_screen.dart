// Афиша и новости — ТЗ: лента мероприятий (ближайшие первыми), карточка, запись, архив, новости
// Визуал и тон: piligrim_design_spec.md (§6 карточки, §8 герой, §9 мероприятия / «АУА»)
// Design plan: Phase 4 — water-pill switcher, steppe-hairline section heads, badge-driven event cards.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/piligrim_route.dart';
import '../core/theme.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../providers/auth_provider.dart';

import '../providers/events_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/event_cover_image.dart'
    show EventCoverImage, PiligrimNetworkOrAssetImage;
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_toast.dart';
import 'event_detail_screen.dart';
import 'event_edit_screen.dart';
import 'event_photo_report_screen.dart';
import 'news_edit_screen.dart';
import '../widgets/piligrim_tab_editorial_mark.dart';
import '../widgets/piligrim_segmented_control.dart';
import '../widgets/piligrim_tap.dart';

enum _AfichaView { events, news }

// Экран афиши: лента мероприятий, архив прошедших и новости ресторана
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  _AfichaView _view = _AfichaView.events;
  bool _archiveOpen = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<EventsProvider>(
      builder: (context, events, _) {
        final upcoming = events.upcoming;
        final past = events.archived;
        final news = events.news;
        final isAdmin = context.watch<AuthProvider>().isAdmin;

        return Scaffold(
      backgroundColor: PiligrimColors.earth,
      extendBodyBehindAppBar: true,
      extendBody: true,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom -
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: AnimatedOpacity(
        opacity: isAdmin ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !isAdmin,
          child: FloatingActionButton(
            heroTag: 'events_fab',
            backgroundColor: PiligrimColors.earthWarm,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: PiligrimColors.water.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(Icons.add, color: PiligrimColors.water),
            onPressed: () {
              if (_view == _AfichaView.events) {
                Navigator.of(context).push(PiligrimPageRoute<void>(
                  builder: (_) => const EventEditScreen(event: null),
                ));
              } else {
                Navigator.of(context).push(PiligrimPageRoute<void>(
                  builder: (_) => const NewsEditScreen(news: null),
                ));
              }
            },
          ),
        ),
      ),
      ),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 16,
                      20,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PiligrimTabEditorialMark(
                          label: 'EVENTS',
                          compact: true,
                        ),
                        const SizedBox(height: PiligrimSpacing.tabEditorialMarkGap),
                        Align(
                          alignment: Alignment.centerRight,
                          child: PiligrimSegmentedControl(
                            tabs: const ['Афиша', 'Новости'],
                            selectedIndex: _view == _AfichaView.events ? 0 : 1,
                            onChanged: (i) => setState(
                              () => _view = i == 0
                                  ? _AfichaView.events
                                  : _AfichaView.news,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_view == _AfichaView.events) ...[
                  if (events.isLoadingUpcoming && upcoming.isEmpty)
                    const SliverToBoxAdapter(child: _EventsLoadingSkeleton()),
                  if (events.upcomingError != null && upcoming.isEmpty)
                    SliverErrorView(
                      message: events.upcomingError!,
                      onRetry: () => context.read<EventsProvider>().retry(),
                    ),
                  const SliverToBoxAdapter(
                    child: _AfichaSectionHeader(label: 'БЛИЖАЙШИЕ СОБЫТИЯ'),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (!events.isLoadingUpcoming &&
                      events.upcomingError == null &&
                      upcoming.isEmpty)
                    const SliverToBoxAdapter(
                      child: _AfichaEmpty(
                        totem: 'assets/images/tree_totem (1).svg',
                        title: 'Пока нет ближайших событий',
                        hint: 'Новые маршруты появятся скоро',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final e = upcoming[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _EventListCard(
                                event: e,
                                coverFallbackIndex: i,
                                isAdmin: isAdmin,
                                onOpen: () {
                                  Navigator.of(context).push(
                                    PiligrimPageRoute<void>(
                                      builder: (_) => EventDetailScreen(
                                        event: e,
                                        coverFallbackIndex: i,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: upcoming.length,
                        ),
                      ),
                    ),
                  if (events.isLoadingArchived &&
                      past.isEmpty &&
                      events.archivedError == null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _ArchiveLoadingSkeleton(),
                      ),
                    ),
                  if (events.archivedError != null && past.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: PiligrimInlineError(
                          message: events.archivedError!,
                          onRetry: () =>
                              context.read<EventsProvider>().retryArchived(),
                        ),
                      ),
                    ),
                  if (past.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                        child: _ArchiveHeader(
                          expanded: _archiveOpen,
                          count: past.length,
                          onToggle: () =>
                              setState(() => _archiveOpen = !_archiveOpen),
                        ),
                      ),
                    ),
                  if (past.isNotEmpty && _archiveOpen)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final e = past[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i < past.length - 1 ? 12 : 0,
                              ),
                              child: _PastEventCard(
                                event: e,
                                coverFallbackIndex: i,
                                isAdmin: isAdmin,
                                onOpen: () {
                                  Navigator.of(context).push(
                                    PiligrimPageRoute(
                                      builder: (_) => EventDetailScreen(
                                        event: e,
                                        coverFallbackIndex: i,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: past.length,
                        ),
                      ),
                    ),
                ] else ...[
                  const SliverToBoxAdapter(
                    child: _AfichaSectionHeader(label: 'НОВОСТИ РЕСТОРАНА'),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (events.isLoadingNews && news.isEmpty)
                    const SliverToBoxAdapter(child: _NewsLoadingSkeleton())
                  else if (events.newsError != null && news.isEmpty)
                    SliverErrorView(
                      message: events.newsError!,
                      onRetry: () =>
                          context.read<EventsProvider>().retryNews(),
                    )
                  else if (news.isEmpty)
                    const SliverToBoxAdapter(
                      child: _AfichaEmpty(
                        totem: 'assets/images/spiral.svg',
                        title: 'Пока нет новостей',
                        hint: 'Загляните позже — ритм заведения меняется',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final n = news[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NewsCard(post: n, isAdmin: isAdmin),
                          );
                          },
                          childCount: news.length,
                        ),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
        ],
      ),
        );
      },
    );
  }
}

// Универсальный section-header «нить пути»: caps + steppe → transparent hairline.
class _AfichaSectionHeader extends StatelessWidget {
  const _AfichaSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: PiligrimTextStyles.sectionLabel.copyWith(
              color: PiligrimColors.steppe.withValues(alpha: 0.82),
              letterSpacing: 2.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.45),
                    PiligrimColors.steppe.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка одного предстоящего мероприятия в списке.
// Дизайн: обложка с water-pill даты (top-left) и format-badge (bottom-right),
// steppe-left-accent-line, многоступенчатый gradient, sky-heading + water-date.
class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.event,
    required this.coverFallbackIndex,
    required this.isAdmin,
    required this.onOpen,
  });

  final ApiEvent event;
  final int coverFallbackIndex;
  final bool isAdmin;
  final VoidCallback onOpen;

  String _priceLine() {
    if (event.priceFrom == null) return 'Стоимость уточняется';
    final formatted = '${event.priceFrom}'.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
    return 'от $formatted ₸';
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = event.format == ApiEventFormat.open;
    return PiligrimTap(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: PiligrimShadows.card,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PiligrimColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Фоновая обложка full-bleed
                EventCoverImage(
                  imageUrl: event.coverUrl,
                  fallbackAsset: event.fallbackCoverAsset(coverFallbackIndex),
                ),

                // Многоступенчатый градиент снизу для читаемости текста
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
                        stops: [0.0, 0.35, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),

                // Format-badge (top-right) + кнопка редактирования рядом для админа
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FormatBadge(isOpen: isOpen),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        _AdminEditButton(
                          onTap: () => _openEventEdit(context, event),
                        ),
                      ],
                    ],
                  ),
                ),

                // Текстовый блок снизу: заголовок + дата + цена
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 20,
                            color: PiligrimColors.sky,
                            height: 1.22,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatDateTimeRu(event.startsAt),
                          style: PiligrimTextStyles.caption.copyWith(
                            color: PiligrimColors.water.withValues(alpha: 0.95),
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _priceLine(),
                          style: PiligrimTextStyles.caption.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            color: PiligrimColors.steppe.withValues(alpha: 0.78),
                          ),
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

  void _openEventEdit(BuildContext context, ApiEvent event) {
    Navigator.of(context).push(PiligrimPageRoute<void>(
      builder: (_) => EventEditScreen(event: event),
    ));
  }
}

// Format-badge на обложке: Открытое (water-tint) / Закрытое (steppe-tint).
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final accent = isOpen
        ? PiligrimColors.water.withValues(alpha: 0.45)
        : PiligrimColors.steppe.withValues(alpha: 0.55);
    final label = isOpen ? 'ОТКРЫТОЕ' : 'ЗАКРЫТОЕ';
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PiligrimColors.cardOverlay,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: PiligrimTextStyles.micro.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.85),
                letterSpacing: 0.8,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Аккордеон архива прошедших — water-totem, steppe-hairline, плавный chevron.
class _ArchiveHeader extends StatelessWidget {
  const _ArchiveHeader({
    required this.expanded,
    required this.count,
    required this.onToggle,
  });

  final bool expanded;
  final int count;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: expanded
              ? PiligrimColors.earthDeep.withValues(alpha: 0.55)
              : PiligrimColors.earth.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded
                ? PiligrimColors.water.withValues(alpha: 0.28)
                : PiligrimColors.divider,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/images/wheel_totem (1).svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    PiligrimColors.water.withValues(alpha: 0.55),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'АРХИВ ПРОШЕДШИХ',
                        style: PiligrimTextStyles.caption.copyWith(
                          letterSpacing: 1.6,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PiligrimColors.sky.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count мероприятий · фотоотчёты по метке',
                        style: PiligrimTextStyles.caption.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.3,
                          color: PiligrimColors.sky.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.125 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    '+',
                    style: PiligrimTextStyles.title.copyWith(
                      fontSize: 22,
                      height: 1.0,
                      color: PiligrimColors.water.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Тонкая steppe-hairline — единый штрих с section headers
            Container(
              height: 1,
              width: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.45),
                    PiligrimColors.steppe.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка прошедшего мероприятия — тонкая matte-вуаль на обложке,
// «Фотоотчёт» chip (water-tint) если доступен фотоотчёт.
// Администратор видит кнопки удаления и управления фотоотчётом.
class _PastEventCard extends StatelessWidget {
  const _PastEventCard({
    required this.event,
    required this.coverFallbackIndex,
    required this.isAdmin,
    required this.onOpen,
  });

  final ApiEvent event;
  final int coverFallbackIndex;
  final bool isAdmin;
  final VoidCallback onOpen;

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PiligrimColors.divider),
        ),
        title: Text(
          'Удалить мероприятие?',
          style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
        ),
        content: Text(
          'Вы хотите удалить «${event.title}»? Это действие нельзя отменить.',
          style: PiligrimTextStyles.body
              .copyWith(color: PiligrimColors.sky.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Отмена',
                style:
                    PiligrimTextStyles.button.copyWith(color: PiligrimColors.water)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await context.read<EventsProvider>().deleteArchivedEvent(event.id);
              } catch (_) {
                if (context.mounted) {
                  PiligrimToast.show(
                    context,
                    'Не удалось удалить мероприятие',
                    type: PiligrimToastType.error,
                  );
                }
              }
            },
            child: Text('Удалить',
                style:
                    PiligrimTextStyles.button.copyWith(color: PiligrimColors.fruit)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PiligrimColors.divider),
        ),
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 76,
                    height: 92,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EventCoverImage(
                          imageUrl: event.coverUrl,
                          fallbackAsset:
                              event.fallbackCoverAsset(coverFallbackIndex),
                        ),
                        // Тонкая matte-вуаль для «архивного» ощущения
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: PiligrimColors.earth.withValues(alpha: 0.22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Отступ справа, чтобы заголовок не перекрывался кнопками
                      Padding(
                        padding:
                            EdgeInsets.only(right: isAdmin ? 72.0 : 0.0),
                        child: Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: PiligrimColors.sky.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatShortDateRu(event.startsAt),
                        style: PiligrimTextStyles.caption.copyWith(
                          color: PiligrimColors.sky.withValues(alpha: 0.38),
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (event.hasPhotoReport) ...[
                        const SizedBox(height: 8),
                        _PhotoReportChip(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Кнопки администратора: фотоотчёт + удалить
            if (isAdmin)
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AdminIconButton(
                      icon: Icons.photo_library_outlined,
                      onTap: () => Navigator.of(context).push(
                        PiligrimPageRoute<void>(
                          builder: (_) =>
                              EventPhotoReportScreen(event: event),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _AdminIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: PiligrimColors.fruit,
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Маленькая иконка-кнопка для действий администратора на карточках архива.
class _AdminIconButton extends StatelessWidget {
  const _AdminIconButton({
    required this.icon,
    required this.onTap,
    this.color = PiligrimColors.water,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

// Micro-chip «Фотоотчёт» для архивной карточки — water-tinted dot + caps.
class _PhotoReportChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PiligrimColors.water.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PiligrimColors.water.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: PiligrimColors.water.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'ФОТООТЧЁТ',
            style: PiligrimTextStyles.micro.copyWith(
              color: PiligrimColors.water.withValues(alpha: 0.85),
              letterSpacing: 0.8,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка новости — редакционный стиль: image full-bleed, текст на фоне приложения.
class _NewsCard extends StatefulWidget {
  const _NewsCard({required this.post, required this.isAdmin});
  final PiligrimNewsPost post;
  final bool isAdmin;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _expanded = false;

  static const _previewLines = 3;
  static const _previewThreshold = 120;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final bodyLong = post.body.length > _previewThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Обложка full-bleed с градиентом, как у карточек событий
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.8,
                  child: PiligrimNetworkOrAssetImage(
                    source: post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                          Color(0x880E0B09),
                          Color(0xCC0E0B09),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _AdminEditButton(
                      onTap: () => _openNewsEdit(context, post),
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Заголовок со steppe-dot
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9, right: 8),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: PiligrimColors.steppe.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PiligrimTextStyles.heading.copyWith(
                  fontSize: 18,
                  height: 1.28,
                  color: PiligrimColors.sky,
                ),
              ),
            ),
            if (widget.isAdmin && !hasImage)
              _AdminEditButton(onTap: () => _openNewsEdit(context, post)),
          ],
        ),

        const SizedBox(height: 6),

        // Дата
        Text(
          formatShortDateRu(post.publishedAt),
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.water.withValues(alpha: 0.85),
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 10),

        // Превью тела — 3 строки, раскрывается по кнопке
        Text(
          post.body,
          maxLines: _expanded ? null : _previewLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 14,
            height: 1.62,
            color: PiligrimColors.sky.withValues(alpha: 0.72),
          ),
        ),

        if (bodyLong && !_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Читать далее →',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.water,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

        // Hairline-разделитель между карточками
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Container(
            height: 0.5,
            color: PiligrimColors.sky.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  void _openNewsEdit(BuildContext context, PiligrimNewsPost post) {
    Navigator.of(context).push(PiligrimPageRoute<void>(
      builder: (_) => NewsEditScreen(news: post),
    ));
  }
}

// Пустое состояние — тотем + caption + подсказка.
// Совпадает по тону с _ClassicEmptyState из MenuScreen.
class _AfichaEmpty extends StatelessWidget {
  const _AfichaEmpty({
    required this.totem,
    required this.title,
    required this.hint,
  });

  final String totem;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          SvgPicture.asset(
            totem,
            width: 44,
            height: 44,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.22),
              BlendMode.srcIn,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then()
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.04, 1.04),
                duration: 2600.ms,
              ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.45),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.30),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Круглая кнопка карандаша для администратора — 36×36, water-иконка.
class _AdminEditButton extends StatelessWidget {
  const _AdminEditButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: PiligrimColors.water.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: const Icon(
          Icons.edit_outlined,
          color: PiligrimColors.water,
          size: 16,
        ),
      ),
    );
  }
}

// Skeleton для загрузки — 2 placeholder-карточки с breathing-animation.
// Создаёт ощущение готовящегося контента вместо «голого» spinner'а.
class _EventsLoadingSkeleton extends StatelessWidget {
  const _EventsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SkeletonRow(height: 124, delayMs: i * 120),
            ),
        ],
      ),
    );
  }
}

class _NewsLoadingSkeleton extends StatelessWidget {
  const _NewsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SkeletonRow(height: 220, delayMs: i * 120),
            ),
        ],
      ),
    );
  }
}

class _ArchiveLoadingSkeleton extends StatelessWidget {
  const _ArchiveLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: _SkeletonRow(height: 56),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.height, this.delayMs = 0});
  final double height;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 600.ms, delay: delayMs.ms)
        .then()
        .fade(
          begin: 1.0,
          end: 0.55,
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}
