// Полноэкранный просмотр фотографий интерьера с зумом, листанием и подписями
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';
import '../data/models/interior_slide.dart';
import '../widgets/piligrim_nav_button.dart';
import '../widgets/piligrim_shimmer.dart';

/// Fullscreen-просмотрщик фотографий интерьера.
///
/// Открывается через [PageRouteBuilder] с [FadeTransition] + [ScaleTransition].
/// Поддерживает pinch-to-zoom, листание между фото и свайп вниз для закрытия.
class InteriorPhotoViewer extends StatefulWidget {
  const InteriorPhotoViewer({
    super.key,
    required this.slides,
    required this.initialIndex,
  });

  // Отфильтрованные по зоне фото (те что показываются в сетке)
  final List<InteriorSlide> slides;
  // Индекс тапнутого фото — открывается сразу на нём
  final int initialIndex;

  @override
  State<InteriorPhotoViewer> createState() => _InteriorPhotoViewerState();
}

class _InteriorPhotoViewerState extends State<InteriorPhotoViewer> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  // Смещение по вертикали при свайпе вниз для закрытия
  double _dragOffset = 0;
  // Прозрачность фона при свайпе (затухает до 0)
  double _bgOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Реагируем только на движение вниз
    if (details.delta.dy <= 0 && _dragOffset <= 0) return;
    setState(() {
      _dragOffset += details.delta.dy;
      if (_dragOffset < 0) _dragOffset = 0;
      // Фон затухает по мере свайпа: при 150px — полностью прозрачный
      _bgOpacity = (1.0 - (_dragOffset / 150)).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final vel = details.velocity.pixelsPerSecond.dy;
    // Закрываем при быстром свайпе или достаточном смещении
    if (vel > 400 || _dragOffset > 100) {
      Navigator.of(context).pop();
    } else {
      // Пружина обратно
      setState(() {
        _dragOffset = 0;
        _bgOpacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_currentIndex];
    final hasCaption = (slide.caption?.isNotEmpty ?? false);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Затемнённый фон, который тускнеет при свайпе вниз
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _bgOpacity,
              duration: Duration.zero,
              child: const ColoredBox(color: Colors.black),
            ),
          ),

          // Основной PageView с фото
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    boundaryMargin: const EdgeInsets.all(20),
                    child: SizedBox.expand(
                      child: CachedNetworkImage(
                        imageUrl: widget.slides[i].imageUrl,
                        // fitWidth — фото всегда занимает полную ширину экрана,
                        // для portrait-кадров заполняет и высоту
                        fit: BoxFit.fitWidth,
                        memCacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                        placeholder: (_, __) => const PiligrimShimmer(),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: PiligrimColors.earthDeep,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Кнопка назад — левый верхний угол
          Positioned(
            top: topPad + 8,
            left: 8,
            child: PiligrimNavButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // Счётчик фото — по центру сверху
          if (widget.slides.length > 1)
            Positioned(
              top: topPad + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.slides.length}',
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: PiligrimColors.sky.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),

          // Подпись и зона внизу (только если есть caption или zoneDisplay)
          if (hasCaption || slide.zoneDisplay.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CaptionOverlay(
                slide: slide,
                bottomPad: bottomPad,
              ),
            ),
        ],
      )
          .animate()
          .fadeIn(duration: 220.ms)
          .scale(
            begin: const Offset(0.94, 0.94),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}


// Нижний оверлей с подписью и названием зоны
class _CaptionOverlay extends StatelessWidget {
  const _CaptionOverlay({required this.slide, required this.bottomPad});
  final InteriorSlide slide;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final hasCaption = slide.caption?.isNotEmpty ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            PiligrimColors.earthDeep.withValues(alpha: 0.90),
            PiligrimColors.earthDeep.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPad + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slide.zoneDisplay.isNotEmpty)
            Text(
              slide.zoneDisplay.toUpperCase(),
              style: PiligrimTextStyles.sectionLabel.copyWith(
                color: PiligrimColors.steppe.withValues(alpha: 0.85),
                letterSpacing: 2.0,
              ),
            ),
          if (slide.zoneDisplay.isNotEmpty && hasCaption)
            const SizedBox(height: 4),
          if (hasCaption)
            Text(
              slide.caption!,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                height: 1.5,
                color: PiligrimColors.sky.withValues(alpha: 0.90),
              ),
            ),
        ],
      ),
    );
  }
}
