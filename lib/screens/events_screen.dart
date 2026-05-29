// Афиша и новости — ТЗ: лента мероприятий (ближайшие первыми), карточка, запись, архив, новости
// Визуал и тон: piligrim_design_spec.md (§6 карточки, §8 герой, §9 мероприятия / «АУА»)
// Design plan: Phase 4 — water-pill switcher, steppe-hairline section heads, badge-driven event cards.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/interior_assets.dart';
import '../core/piligrim_route.dart';
import '../core/theme.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../providers/auth_provider.dart';
import '../providers/core_info_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/event_cover_image.dart'
    show EventCoverImage, PiligrimNetworkOrAssetImage;
import '../widgets/piligrim_background.dart';
import 'event_detail_screen.dart';
import 'event_edit_screen.dart';
import 'event_photo_report_screen.dart';
import 'news_edit_screen.dart';
import '../widgets/piligrim_tab_editorial_mark.dart';
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
  int _heroIndex = 0;

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
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _SegmentedAficha(
                            value: _view,
                            onChanged: (v) => setState(() => _view = v),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Builder(builder: (context) {
                          // Берём URL-слайды из CoreInfo; если ещё не загружены — фоллбэк на локальные PNG
                          final coreInfo = context.watch<CoreInfoProvider>().coreInfo;
                          final imageUrls =
                              (coreInfo?.heroImageUrls.isNotEmpty == true)
                                  ? coreInfo!.heroImageUrls
                                  : PiligrimInteriorAssets.triptychInteriorAmbient;
                          return _AfishaHero(
                            selectedIndex: _heroIndex,
                            onChanged: (index) => setState(() => _heroIndex = index),
                            imageUrls: imageUrls,
                          );
                        }),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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

// Переключатель «Афиша» / «Новости» — тот же water-pill, что _ModeSwitcher в Menu.
class _SegmentedAficha extends StatelessWidget {
  const _SegmentedAficha({
    required this.value,
    required this.onChanged,
  });

  final _AfichaView value;
  final ValueChanged<_AfichaView> onChanged;

  static const double _height = 36;
  static const double _radius = 18;
  static const double _trackWidth = 184;
  /// Внутренний воздух между track border и active pill (Apple-style inset).
  static const double _pillInset = 3;

  @override
  Widget build(BuildContext context) {
    final isEvents = value == _AfichaView.events;
    const innerWidth = _trackWidth - _pillInset * 2;
    const pillWidth = innerWidth / 2;
    const pillRadius = _radius - _pillInset;

    return SizedBox(
      width: _trackWidth,
      height: _height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PiligrimColors.earthDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: PiligrimColors.divider),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_pillInset),
              child: AnimatedAlign(
                duration: 280.ms,
                curve: Curves.easeOutCubic,
                alignment: isEvents
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: PiligrimColors.water.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(pillRadius),
                    border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PiligrimColors.water.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _AfichaTabLabel(
                  label: 'Афиша',
                  active: isEvents,
                  onTap: () => onChanged(_AfichaView.events),
                ),
              ),
              Expanded(
                child: _AfichaTabLabel(
                  label: 'Новости',
                  active: !isEvents,
                  onTap: () => onChanged(_AfichaView.news),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AfichaTabLabel extends StatelessWidget {
  const _AfichaTabLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? PiligrimColors.water
        : PiligrimColors.sky.withValues(alpha: 0.45);

    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );

    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_SegmentedAficha._radius),
      child: SizedBox(
        height: _SegmentedAficha._height,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -0.5),
            child: AnimatedDefaultTextStyle(
              duration: 220.ms,
              curve: Curves.easeOut,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w300,
                letterSpacing: active ? 0.6 : 0.4,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                textHeightBehavior: textHeightBehavior,
                strutStyle: const StrutStyle(
                  fontSize: 11.5,
                  height: 1.0,
                  leading: 0,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
      ),
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


// Большой слайдер с фотографиями пространства и кнопкой действия
class _AfishaHero extends StatefulWidget {
  const _AfishaHero({
    required this.selectedIndex,
    required this.onChanged,
    required this.imageUrls,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  // Список URL (сетевых или asset-путей) для слайдов
  final List<String> imageUrls;

  int get _slideCount => imageUrls.length;

  _HeroItem itemForSlide(int index) {
    final image = imageUrls[index];
    const titles = [
      'Атмосфера зала',
      'Ритуал вечера',
      'Гастрономическое странствие',
    ];
    const subtitles = [
      'Ивент-спейс АУА · тёплый вечерний свет',
      'Путь героя начинается с живого ритма',
      'Авторские ужины, где кухня говорит образами',
    ];
    const ctas = [
      'Смотреть события',
      'Выбрать ритуал',
      'Открыть афишу',
    ];
    const totems = [
      'assets/images/moon_totem (1).svg',
      'assets/images/tree_totem (1).svg',
      'assets/images/star_totem (1).svg',
    ];
    final t = index % 3;
    final chip = 'ПРОСТРАНСТВО ${(index + 1).toString().padLeft(2, '0')}';
    return _HeroItem(
      title: titles[t],
      subtitle: subtitles[t],
      cta: ctas[t],
      imageAsset: image,
      totemAsset: totems[t],
      chip: chip,
    );
  }

  @override
  State<_AfishaHero> createState() => _AfishaHeroState();
}

class _AfishaHeroState extends State<_AfishaHero> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final maxI = widget._slideCount - 1;
    final page = widget.selectedIndex.clamp(0, maxI < 0 ? 0 : maxI);
    _controller = PageController(
      viewportFraction: 0.94,
      initialPage: page,
    );
    // Предзагружаем первые 3 слайда сразу после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload(page));
  }

  // Предзагрузка текущего + соседних слайдов через CachedNetworkImageProvider
  void _preload(int current) {
    if (!mounted) return;
    final urls = widget.imageUrls;
    for (var offset = -1; offset <= 1; offset++) {
      final i = current + offset;
      if (i < 0 || i >= urls.length) continue;
      final url = urls[i];
      if (url.startsWith('http')) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AfishaHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final maxI = widget._slideCount - 1;
      final target = widget.selectedIndex.clamp(0, maxI < 0 ? 0 : maxI);
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final maxI = widget._slideCount - 1;
    final i = index.clamp(0, maxI < 0 ? 0 : maxI);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget._slideCount;
    final idx = widget.selectedIndex.clamp(0, total > 0 ? total - 1 : 0);
    return Column(
      children: [
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.24).clamp(160.0, 220.0),
          child: PageView.builder(
            itemCount: total,
            controller: _controller,
            onPageChanged: (page) {
              widget.onChanged(page);
              _preload(page); // предзагружаем соседей при свайпе
            },
            itemBuilder: (context, index) {
              final item = widget.itemForSlide(index);
              final active = idx == index;
              return _HeroSlide(
                item: item,
                active: active,
                onTap: () => _goTo(index),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _HeroDotsIndicator(count: total, current: idx),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Точечный индикатор слайдера hero — активная точка water (растянута), остальные sky @0.18.
class _HeroDotsIndicator extends StatelessWidget {
  const _HeroDotsIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: 260.ms,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 6,
          height: 4,
          decoration: BoxDecoration(
            color: active
                ? PiligrimColors.water.withValues(alpha: 0.85)
                : PiligrimColors.sky.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: PiligrimColors.water.withValues(alpha: 0.30),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// Одна карточка-слайд внутри hero-слайдера (фото + заголовок + кнопка)
class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _HeroItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1 : 0.985,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: PiligrimTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PiligrimColors.sky.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: PiligrimColors.earth.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: active ? 1.04 : 1.0,
                alignment: Alignment.center,
                child: item.imageAsset.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: item.imageAsset,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        memCacheHeight: 500,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, __) => const ColoredBox(
                          color: PiligrimColors.earthDeep,
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          PiligrimInteriorAssets.triptychInteriorAmbient[0],
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(item.imageAsset, fit: BoxFit.cover),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PiligrimColors.earth.withValues(alpha: 0.0),
                      PiligrimColors.earth.withValues(alpha: 0.15),
                      PiligrimColors.earth.withValues(alpha: 0.55),
                      PiligrimColors.earth.withValues(alpha: 0.88),
                      PiligrimColors.earth,
                    ],
                    stops: const [0.0, 0.25, 0.55, 0.78, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PiligrimColors.earthDeep.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    item.chip,
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.92),
                      letterSpacing: 1.0,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: SvgPicture.asset(
                  item.totemAsset,
                  width: 98,
                  height: 98,
                  colorFilter: ColorFilter.mode(
                    PiligrimColors.water.withValues(alpha: 0.16),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      item.title,
                      style: PiligrimTextStyles.heading.copyWith(
                        color: PiligrimColors.sky,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PiligrimTap(
                      onTap: onTap,
                      borderRadius: PiligrimRadius.smAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: PiligrimColors.steppe.withValues(alpha: 0.22),
                          borderRadius: PiligrimRadius.smAll,
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.cta.toUpperCase(),
                              style: PiligrimTextStyles.button.copyWith(
                                color: PiligrimColors.sky,
                                fontSize: 11,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '→',
                              style: PiligrimTextStyles.caption.copyWith(
                                color: PiligrimColors.sky.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

// Модель данных для одного слайда hero-карусели
class _HeroItem {
  const _HeroItem({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.imageAsset,
    required this.totemAsset,
    required this.chip,
  });

  final String title;
  final String subtitle;
  final String cta;
  final String imageAsset;
  final String totemAsset;
  final String chip;
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

  String _dateBadgeText() {
    final d = event.startsAt;
    final m = const [
      'ЯНВ', 'ФЕВ', 'МАР', 'АПР', 'МАЙ', 'ИЮН',
      'ИЮЛ', 'АВГ', 'СЕН', 'ОКТ', 'НОЯ', 'ДЕК',
    ][d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} $m · $hh:$mm';
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

                // Steppe-левая акцентная полоса
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: PiligrimColors.steppe.withValues(alpha: 0.8),
                  ),
                ),

                // Water-pill даты (top-left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _DateBadge(text: _dateBadgeText()),
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

// Water-pill даты на обложке мероприятия.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PiligrimColors.cardOverlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PiligrimColors.water.withValues(alpha: 0.38),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        textAlign: TextAlign.center,
        style: PiligrimTextStyles.micro.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.92),
          letterSpacing: 0.6,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
        border: Border.all(color: accent, width: 0.8),
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
                fontSize: 9,
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
                  width: 22,
                  height: 22,
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Не удалось удалить мероприятие',
                        style: PiligrimTextStyles.body
                            .copyWith(color: PiligrimColors.sky)),
                    backgroundColor: PiligrimColors.earthDeep,
                  ));
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Icon(icon, color: color, size: 14),
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка новости — steppe-accent line, steppe-dot перед title,
// тонкий sky-divider между датой и body.
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post, required this.isAdmin});
  final PiligrimNewsPost post;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
        boxShadow: PiligrimShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PiligrimColors.steppe.withValues(alpha: 0.55),
                      PiligrimColors.steppe.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.imageUrl != null &&
                          post.imageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: PiligrimRadius.smAll,
                          child: Stack(
                            children: [
                              PiligrimNetworkOrAssetImage(
                                source: post.imageUrl!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                              // Лёгкий gradient bottom-overlay для глубины
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 60,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        PiligrimColors.earthDeep
                                            .withValues(alpha: 0.0),
                                        PiligrimColors.earthDeep
                                            .withValues(alpha: 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Title со steppe-dot префиксом
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 9, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: PiligrimColors.steppe
                                    .withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              post.title,
                              style: PiligrimTextStyles.heading.copyWith(
                                fontSize: 17,
                                height: 1.3,
                                color: PiligrimColors.sky,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Дата + mini hairline-divider
                      Row(
                        children: [
                          Text(
                            formatShortDateRu(post.publishedAt),
                            style: PiligrimTextStyles.caption.copyWith(
                              color: PiligrimColors.water
                                  .withValues(alpha: 0.85),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 20,
                            height: 1,
                            color: PiligrimColors.sky.withValues(alpha: 0.10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post.body,
                        style: PiligrimTextStyles.body.copyWith(
                          fontSize: 14,
                          height: 1.6,
                          color: PiligrimColors.sky.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
              ),
            ),
            // Кнопка редактирования — показывается только администратору
            if (isAdmin)
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SkeletonRow(height: 110, delayMs: i * 120),
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
      padding: EdgeInsets.symmetric(horizontal: 20),
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
