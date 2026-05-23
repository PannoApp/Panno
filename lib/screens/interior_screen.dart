// Экран «Интерьер» — галерея пространства с фильтрами по зонам, зумом и 3D-туром
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';
import '../data/models/interior_slide.dart';
import '../providers/core_info_provider.dart';
import '../widgets/interior_zone_filter.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_shimmer.dart';
import '../widgets/piligrim_tap.dart';
import 'interior_photo_viewer.dart';
import 'tour_webview_screen.dart';

class InteriorScreen extends StatefulWidget {
  const InteriorScreen({super.key, this.isTabActive = true});

  // Передаётся из RootShell — нужен для паузы аудио при переключении вкладок
  final bool isTabActive;

  @override
  State<InteriorScreen> createState() => _InteriorScreenState();
}

class _InteriorScreenState extends State<InteriorScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  // Выбранная зона фильтра (null = показывать все фото)
  String? _selectedZone;

  // Плеер атмосферного эмбиента
  late final AudioPlayer _audioPlayer;
  bool _isMuted = false;
  // Становится true после успешного запуска аудио — тогда показываем кнопку
  bool _audioInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addObserver(this);
    _startAmbientAudio();
  }

  Future<void> _startAmbientAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.45);
      await _audioPlayer.play(AssetSource('audio/interior_ambient.mp3'));
      if (mounted) setState(() => _audioInitialized = true);
    } catch (e) {
      // Файл недоступен — кнопку просто скрываем, UI не ломается
      debugPrint('InteriorAudio: ошибка запуска: $e');
    }
  }

  @override
  void didUpdateWidget(InteriorScreen old) {
    super.didUpdateWidget(old);
    // IndexedStack не вызывает dispose/initState при переключении вкладок,
    // поэтому управляем аудио через параметр isTabActive
    if (!widget.isTabActive && old.isTabActive) {
      _audioPlayer.pause();
    } else if (widget.isTabActive && !old.isTabActive && !_isMuted) {
      _audioPlayer.resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Пауза при сворачивании приложения в фон
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed && !_isMuted) {
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _isMuted ? _audioPlayer.pause() : _audioPlayer.resume();
  }

  void _openTour(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TourWebViewScreen(url: url),
      ),
    );
  }

  void _openPhoto(List<InteriorSlide> slides, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => InteriorPhotoViewer(
          slides: slides,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<CoreInfoProvider>(
      builder: (context, core, _) {
        final slides = core.interiorSlides;
        final useApi = slides.isNotEmpty;
        final assetPaths = PiligrimInteriorAssets.allInteriorPngs;
        final cacheW = PiligrimInteriorAssets.decodeCacheWidth(context);
        final tourLink = core.coreInfo?.tourLink;

        // Уникальные зоны из API с сохранением порядка (через LinkedHashSet)
        final zones = useApi
            ? slides
                .map((s) => (zone: s.zone, label: s.zoneDisplay))
                .toSet()
                .toList()
            : <({String zone, String label})>[];

        // Фото для текущего фильтра
        final filtered = (_selectedZone == null || !useApi)
            ? (useApi ? slides : <InteriorSlide>[])
            : slides.where((s) => s.zone == _selectedZone).toList();

        // Hero — первое фото текущего фильтра; сетка показывает остальные
        final heroSlide = (useApi && filtered.isNotEmpty) ? filtered[0] : null;
        final gridSlides =
            (useApi && filtered.length > 1) ? filtered.sublist(1) : <InteriorSlide>[];
        final itemCount = useApi ? gridSlides.length : assetPaths.length;
        // Нечётные плитки — последняя одна, рендерим её полноширокой
        final hasOrphan = useApi && itemCount.isOdd && itemCount > 0;
        final pairCount = hasOrphan ? itemCount - 1 : itemCount;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1B19),
          body: Stack(
            children: [
              const Positioned.fill(child: PiligrimBackground(cinematic: true)),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // ── Заголовок ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'ИНТЕРЬЕР',
                                  style: PiligrimTextStyles.sectionLabel
                                      .copyWith(
                                    letterSpacing: 2.8,
                                    color: PiligrimColors.sky
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                const Spacer(),
                                if (_audioInitialized)
                                  _CompactAudioButton(
                                    isMuted: _isMuted,
                                    onToggle: _toggleMute,
                                  )
                                      .animate()
                                      .fadeIn(
                                          delay: 400.ms, duration: 500.ms),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Пространство PILIGRIM',
                              style: PiligrimTextStyles.heading.copyWith(
                                fontSize: 24,
                                color: PiligrimColors.sky,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Тёплый свет, медь и дерево саксаула — атмосфера Modern Nomad.',
                              style: PiligrimTextStyles.body.copyWith(
                                fontSize: 13,
                                height: 1.55,
                                color: PiligrimColors.sky.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Кнопка 3D-тура (если задан в панели управления) ─────
                    if (tourLink != null && tourLink.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                          child: _TourButton(
                            onTap: () => _openTour(tourLink),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 40.ms, duration: 480.ms)
                            .slideY(begin: 0.08, end: 0, duration: 480.ms),
                      ),

                    // ── Загрузка ─────────────────────────────────────────────
                    if (core.isLoading && !useApi)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: PiligrimLoader()),
                        ),
                      ),

                    // ── Фильтр по зонам (если зон больше одной) ──────────────
                    if (zones.length > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: InteriorZoneFilter(
                            zones: zones,
                            selectedZone: _selectedZone,
                            onSelect: (z) {
                              setState(() => _selectedZone = z);
                            },
                          ),
                        ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                      ),

                    // ── Hero-фото (первое из текущего фильтра) ────────────────
                    if (heroSlide != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.97,
                                  end: 1.0,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            ),
                            child: _HeroPhotoBlock(
                              key: ValueKey(heroSlide.imageUrl),
                              slide: heroSlide,
                              cacheWidth: cacheW,
                              onTap: () => _openPhoto(filtered, 0),
                            ),
                          ),
                        ),
                      ),

                    // ── Путевой разделитель ───────────────────────────────────
                    if (heroSlide != null && itemCount > 0)
                      SliverToBoxAdapter(
                        child: const _PathDivider()
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms),
                      ),

                    // ── Сетка оставшихся фотографий (парные плитки) ──────────
                    if (itemCount > 0)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            20, 8, 20, hasOrphan ? 0 : 120),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (useApi) {
                                return _InteriorSlideTile(
                                  slide: gridSlides[i],
                                  cacheWidth: cacheW,
                                  onTap: () => _openPhoto(filtered, i + 1),
                                )
                                    .animate(
                                        delay: Duration(
                                            milliseconds: 80 + i * 35))
                                    .fadeIn(duration: 380.ms);
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  assetPaths[i],
                                  fit: BoxFit.cover,
                                  cacheWidth: cacheW,
                                ),
                              );
                            },
                            childCount: pairCount,
                          ),
                        ),
                      ),

                    // ── Одинокая последняя плитка — полная ширина ─────────────
                    if (hasOrphan)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        sliver: SliverToBoxAdapter(
                          child: SizedBox(
                            height: 200,
                            child: _InteriorSlideTile(
                              slide: gridSlides.last,
                              cacheWidth: cacheW,
                              onTap: () => _openPhoto(filtered, itemCount),
                            )
                                .animate(
                                    delay: Duration(
                                        milliseconds: 80 + itemCount * 35))
                                .fadeIn(duration: 380.ms),
                          ),
                        ),
                      ),

                    if (itemCount == 0)
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),

            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Большое hero-фото — первое фото текущего фильтра
// ─────────────────────────────────────────────────────────────────────────────
class _HeroPhotoBlock extends StatelessWidget {
  const _HeroPhotoBlock({
    super.key,
    required this.slide,
    required this.onTap,
    this.cacheWidth,
  });

  final InteriorSlide slide;
  final VoidCallback onTap;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: slide.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: cacheWidth,
                placeholder: (_, __) => const PiligrimShimmer(),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: PiligrimColors.earthDeep),
              ),
              // Верхняя виньетка — плавный переход к тёмному фону сверху
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.30],
                      colors: [Color(0x55000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Нижний градиент — читаемость текста зоны
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.42, 1.0],
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
              ),
              // Метка зоны + иконка-expand в правом нижнем углу
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (slide.zoneDisplay.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slide.zoneDisplay.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PiligrimTextStyles.caption.copyWith(
                                fontSize: 11,
                                letterSpacing: 2.0,
                                color: PiligrimColors.water.withValues(alpha: 0.90),
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: PiligrimColors.sky.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: PiligrimColors.sky.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '↗',
                        style: TextStyle(
                          fontSize: 11,
                          color: PiligrimColors.sky.withValues(alpha: 0.75),
                          height: 1.0,
                          fontFamily: 'MuseoSans',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Плитка одного фото в сетке
// ─────────────────────────────────────────────────────────────────────────────
class _InteriorSlideTile extends StatelessWidget {
  const _InteriorSlideTile({
    required this.slide,
    required this.cacheWidth,
    this.onTap,
  });

  final InteriorSlide slide;
  final int? cacheWidth;
  // null — асетные заглушки не кликабельны
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              placeholder: (_, __) => const PiligrimShimmer(),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: PiligrimColors.earthDeep),
            ),
            // Градиент снизу — создаёт «кино» ощущение
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Color(0xB5000000)],
                  ),
                ),
              ),
            ),
            if (slide.zoneDisplay.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  slide.zoneDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.3,
                    color: PiligrimColors.sky.withValues(alpha: 0.88),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Путевой разделитель между hero и галереей — тонкая линия со звездой-тотемом
// ─────────────────────────────────────────────────────────────────────────────
class _PathDivider extends StatelessWidget {
  const _PathDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PiligrimColors.sky.withValues(alpha: 0.0),
                    PiligrimColors.sky.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PiligrimColors.water.withValues(alpha: 0.30),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PiligrimColors.sky.withValues(alpha: 0.08),
                    PiligrimColors.sky.withValues(alpha: 0.0),
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

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка 3D-тура с брендовым оформлением
// ─────────────────────────────────────────────────────────────────────────────
class _TourButton extends StatelessWidget {
  const _TourButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF2E2420),
              Color(0xFF3A2C22),
            ],
          ),
          border: Border.all(
            color: PiligrimColors.steppe.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PiligrimColors.steppe.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/wheel_totem (1).svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.steppe,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Виртуальный тур',
                    style: PiligrimTextStyles.ctaLabel.copyWith(
                      fontSize: 14,
                      color: PiligrimColors.steppe,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Прогулка по залам PILIGRIM',
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '→',
              style: TextStyle(
                fontSize: 16,
                color: PiligrimColors.steppe.withValues(alpha: 0.55),
                height: 1.0,
                fontFamily: 'MuseoSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Компактная кнопка аудио в заголовке — круглая иконка вместо floating pill
// ─────────────────────────────────────────────────────────────────────────────
class _CompactAudioButton extends StatelessWidget {
  const _CompactAudioButton({
    required this.isMuted,
    required this.onToggle,
  });

  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMuted
              ? Colors.transparent
              : PiligrimColors.steppe.withValues(alpha: 0.14),
          border: Border.all(
            color: isMuted
                ? PiligrimColors.sky.withValues(alpha: 0.13)
                : PiligrimColors.steppe.withValues(alpha: 0.40),
            width: 1,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/cobyz.svg',
            width: 15,
            height: 15,
            colorFilter: ColorFilter.mode(
              isMuted
                  ? PiligrimColors.sky.withValues(alpha: 0.22)
                  : PiligrimColors.steppe,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
