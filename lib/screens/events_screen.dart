// Афиша и новости — ТЗ: лента мероприятий (ближайшие первыми), карточка, запись, архив, новости
// Визуал и тон: piligrim_design_spec.md (§6 карточки, §8 герой, §9 мероприятия / «АУА»)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';
import '../data/events_news_data.dart';
import '../widgets/piligrim_background.dart';
import 'event_detail_screen.dart';
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

  late final List<PiligrimEvent> _allEvents;
  late final List<PiligrimNewsPost> _news;

  @override
  void initState() {
    super.initState();
    _allEvents = buildMockEvents();
    _news = mockNewsPosts();
  }

  void _openPhotoReport(PiligrimEvent e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Фотоотчёт',
                style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
              ),
              const SizedBox(height: 8),
              Text(
                e.title,
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.water,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Подборка кадров с вечера — полная галерея появится в каналах PILIGRIM. Здесь герой видит атмосферу в духе бренда: тёплый свет, детали стола.',
                style: PiligrimTextStyles.body.copyWith(
                  fontSize: 13,
                  color: PiligrimColors.sky.withValues(alpha: 0.85),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final extras =
                      PiligrimInteriorAssets.galleryExtrasExcluding(e.coverAssetPath);
                  Widget galleryThumb(String asset) {
                    return Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(asset, fit: BoxFit.cover),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        PiligrimColors.earth.withValues(alpha: 0.0),
                                        PiligrimColors.earth.withValues(alpha: 0.7),
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

                  return Row(
                    children: [
                      galleryThumb(e.coverAssetPath),
                      const SizedBox(width: 8),
                      galleryThumb(extras[0]),
                      const SizedBox(width: 8),
                      galleryThumb(extras[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Закрыть',
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.water,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final upcoming = upcomingEventsSorted(_allEvents);
    final past = pastEventsSorted(_allEvents);

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      extendBodyBehindAppBar: true,
      extendBody: true,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 12,
                      20,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SvgPicture.asset(
                              'assets/images/tree_totem (1).svg',
                              width: 36,
                              height: 36,
                              colorFilter: const ColorFilter.mode(
                                PiligrimColors.steppe,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'АФИША И НОВОСТИ',
                                    style: PiligrimTextStyles.title.copyWith(
                                      fontSize: 20,
                                      letterSpacing: 2,
                                      color: PiligrimColors.sky,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Лента мероприятий и вестей заведения',
                                    style: PiligrimTextStyles.caption.copyWith(
                                      fontSize: 12,
                                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SegmentedAficha(
                          value: _view,
                          onChanged: (v) => setState(() => _view = v),
                        ),
                        const SizedBox(height: 14),
                        _AfishaHero(
                          selectedIndex: _heroIndex,
                          onChanged: (index) => setState(() => _heroIndex = index),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_view == _AfichaView.events) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'БЛИЖАЙШИЕ СОБЫТИЯ',
                        style: PiligrimTextStyles.caption.copyWith(
                          letterSpacing: 1.6,
                          color: PiligrimColors.steppe.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
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
                              onOpen: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => EventDetailScreen(event: e),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: _ArchiveHeader(
                        expanded: _archiveOpen,
                        count: past.length,
                        onToggle: () => setState(() => _archiveOpen = !_archiveOpen),
                      ),
                    ),
                  ),
                  if (_archiveOpen)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final e = past[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PastEventCard(
                                event: e,
                                onPhotoReport: e.hasPhotoReport
                                    ? () => _openPhotoReport(e)
                                    : null,
                              ),
                            );
                          },
                          childCount: past.length,
                        ),
                      ),
                    ),
                ] else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'НОВОСТИ РЕСТОРАНА',
                        style: PiligrimTextStyles.caption.copyWith(
                          letterSpacing: 1.6,
                          color: PiligrimColors.steppe.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final n = _news[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NewsCard(post: n),
                          );
                        },
                        childCount: _news.length,
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
  }
}

// Переключатель вкладок «Афиша» / «Новости» в верхней части экрана
class _SegmentedAficha extends StatelessWidget {
  const _SegmentedAficha({
    required this.value,
    required this.onChanged,
  });

  final _AfichaView value;
  final ValueChanged<_AfichaView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PiligrimColors.earth.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PiligrimColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegButton(
              label: 'Афиша',
              active: value == _AfichaView.events,
              onTap: () => onChanged(_AfichaView.events),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: 'Новости',
              active: value == _AfichaView.news,
              onTap: () => onChanged(_AfichaView.news),
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
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static int get _slideCount => PiligrimInteriorAssets.allInteriorPngs.length;

  static _HeroItem itemForSlide(int index) {
    final image = PiligrimInteriorAssets.allInteriorPngs[index];
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
    final maxI = _AfishaHero._slideCount - 1;
    final page = widget.selectedIndex.clamp(0, maxI < 0 ? 0 : maxI);
    _controller = PageController(
      viewportFraction: 0.94,
      initialPage: page,
    );
  }

  @override
  void didUpdateWidget(covariant _AfishaHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final maxI = _AfishaHero._slideCount - 1;
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
    final maxI = _AfishaHero._slideCount - 1;
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
    final total = _AfishaHero._slideCount;
    final idx = widget.selectedIndex.clamp(0, total > 0 ? total - 1 : 0);
    return Column(
      children: [
        SizedBox(
          height: 194,
          child: PageView.builder(
            itemCount: total,
            controller: _controller,
            onPageChanged: widget.onChanged,
            itemBuilder: (context, index) {
              final item = _AfishaHero.itemForSlide(index);
              final active = idx == index;
              return _HeroSlide(
                item: item,
                active: active,
                onTap: () => _goTo(index),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: total > 0 ? (idx + 1) / total : 0,
                  minHeight: 3,
                  backgroundColor: PiligrimColors.sky.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    PiligrimColors.water.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$total кадров пространства · ${idx + 1} из $total',
                style: PiligrimTextStyles.caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: PiligrimColors.sky.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ],
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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: active ? 1.04 : 1.0),
                duration: const Duration(seconds: 12),
                curve: Curves.easeInOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Image.asset(item.imageAsset, fit: BoxFit.cover),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: PiligrimColors.earthDeep.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PiligrimColors.steppe.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    item.chip,
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.steppe,
                      letterSpacing: 0.8,
                      fontSize: 10,
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
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PiligrimTap(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PiligrimColors.steppe.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          item.cta,
                          style: PiligrimTextStyles.button.copyWith(
                            color: PiligrimColors.sky,
                            fontSize: 11.5,
                            letterSpacing: 0.6,
                          ),
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

// Кнопка-сегмент внутри переключателя вкладок
class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? PiligrimColors.water.withValues(alpha: 0.35)
              : PiligrimColors.clear,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? PiligrimColors.water.withValues(alpha: 0.5)
                : PiligrimColors.clear,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: PiligrimTextStyles.button.copyWith(
            fontSize: 13,
            letterSpacing: 0.8,
            color: active ? PiligrimColors.sky : PiligrimColors.sky.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

// Карточка одного предстоящего мероприятия в списке (обложка + дата + описание)
class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.event,
    required this.onOpen,
  });

  final PiligrimEvent event;
  final VoidCallback onOpen;

  String _subtitle() {
    final fmt = event.format.labelRu.toLowerCase();
    final price = event.priceFromRub != null ? ' · от ${event.priceFromRub} ₽' : '';
    return '$fmt$price';
  }

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          decoration: BoxDecoration(
            color: PiligrimColors.earth.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PiligrimColors.divider),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        event.coverAssetPath,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                PiligrimColors.earth.withValues(alpha: 0.0),
                                PiligrimColors.earth.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PiligrimTextStyles.heading.copyWith(
                        fontSize: 16,
                        color: PiligrimColors.sky,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDateTimeRu(event.startsAt),
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.water,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle(),
                      style: PiligrimTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: PiligrimColors.steppe.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PiligrimTextStyles.body.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: PiligrimColors.sky.withValues(alpha: 0.65),
                      ),
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

// Заголовок-аккордеон для раскрытия архива прошедших мероприятий
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
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: PiligrimColors.earth.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PiligrimColors.divider),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/wheel_totem (1).svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.sky.withValues(alpha: 0.5),
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
                        letterSpacing: 1.4,
                        color: PiligrimColors.sky.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      '$count мероприятий · фотоотчёты по метке',
                      style: PiligrimTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: PiligrimColors.sky.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                expanded ? '−' : '+',
                style: PiligrimTextStyles.title.copyWith(
                  fontSize: 20,
                  color: PiligrimColors.water,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

// Карточка прошедшего мероприятия (название, дата, ссылка на фотоотчёт)
class _PastEventCard extends StatelessWidget {
  const _PastEventCard({
    required this.event,
    this.onPhotoReport,
  });

  final PiligrimEvent event;
  final VoidCallback? onPhotoReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PiligrimColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: PiligrimTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: PiligrimColors.sky.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatShortDateRu(event.startsAt),
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.35),
            ),
          ),
          if (onPhotoReport != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onPhotoReport,
                style: TextButton.styleFrom(
                  foregroundColor: PiligrimColors.water,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Фотоотчёт',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PiligrimColors.water,
                    decoration: TextDecoration.underline,
                    decorationColor: PiligrimColors.water.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Карточка новости ресторана (заголовок, дата, текст)
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post});
  final PiligrimNewsPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earth.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: PiligrimTextStyles.heading.copyWith(
              fontSize: 17,
              color: PiligrimColors.sky,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatShortDateRu(post.publishedAt),
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.water.withValues(alpha: 0.85),
              fontSize: 12,
            ),
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
    );
  }
}
