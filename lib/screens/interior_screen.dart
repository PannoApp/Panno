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
import '../widgets/interior_audio_button.dart';
import '../widgets/interior_zone_filter.dart';
import '../widgets/piligrim_background.dart';
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

        final itemCount = useApi ? filtered.length : assetPaths.length;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1B19),
          body: Stack(
            children: [
              const Positioned.fill(child: PiligrimBackground(cinematic: true)),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ── Заголовок ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ИНТЕРЬЕР',
                              style: PiligrimTextStyles.sectionLabel.copyWith(
                                letterSpacing: 2.8,
                                color: PiligrimColors.sky.withValues(alpha: 0.55),
                              ),
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
                              useApi
                                  ? 'Кадры залов и зон — с сервера ресторана.'
                                  : 'Тёплый свет, дерево и тишина — атмосфера Modern Nomad.',
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
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: PiligrimColors.water,
                              strokeWidth: 2,
                            ),
                          ),
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

                    // ── Сетка фотографий ──────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
                                slide: filtered[i],
                                cacheWidth: cacheW,
                                onTap: () => _openPhoto(filtered, i),
                              )
                                  .animate(delay: Duration(milliseconds: 60 + i * 30))
                                  .fadeIn(duration: 350.ms);
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
                          childCount: itemCount,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Кнопка аудио — поверх сетки, над навбаром ────────────────
              if (_audioInitialized)
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 88,
                  right: 20,
                  child: InteriorAudioButton(
                    isMuted: _isMuted,
                    onToggle: _toggleMute,
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                ),
            ],
          ),
        );
      },
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
              placeholder: (_, __) =>
                  const ColoredBox(color: PiligrimColors.earthDeep),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: PiligrimColors.earthDeep),
            ),
            if (slide.zoneDisplay.isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  slide.zoneDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: PiligrimColors.sky.withValues(alpha: 0.9),
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: PiligrimColors.steppe.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: PiligrimColors.steppe.withValues(alpha: 0.40),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/wheel_totem (1).svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                PiligrimColors.steppe,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Виртуальный 3D-тур',
              style: PiligrimTextStyles.ctaLabel.copyWith(
                fontSize: 13,
                color: PiligrimColors.steppe,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              '→',
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 13,
                color: PiligrimColors.steppe.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
