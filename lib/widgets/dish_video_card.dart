// DishVideoCard — полноэкранная карточка в стиле Reels / TikTok
// «Каждое блюдо — отдельное приключение» (brandbook, стр. 17)
// Блок 5: переключение на ApiDish, VideoPlayerController при наличии videoUrl.
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../core/theme.dart';
import '../data/models/api_dish.dart';
import '../providers/menu_provider.dart';
import 'dish_detail_sheet.dart';
import 'dish_elements.dart';

class DishVideoCard extends StatefulWidget {
  const DishVideoCard({
    super.key,
    required this.dish,
    required this.isActive,
    this.onSwipeRight,
  });

  final ApiDish dish;
  final bool isActive;
  final VoidCallback? onSwipeRight;

  @override
  State<DishVideoCard> createState() => _DishVideoCardState();
}

class _DishVideoCardState extends State<DishVideoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ambientCtrl;
  VideoPlayerController? _videoCtrl;
  bool _isMuted = true;
  bool _videoError = false;
  bool _loopSeekPending = false;
  // false пока платформенная текстура не отдала первый кадр; shield скрывает чёрный кадр
  bool _videoFirstFrameReady = false;

  bool get _hasVideoSource =>
      widget.dish.videoUrl != null && widget.dish.videoStatus == 'ready';

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (!_hasVideoSource) {
      _ambientCtrl.repeat(reverse: true);
    }

    if (_hasVideoSource) {
      _initVideo(widget.dish.videoUrl!);
    }
  }

  // Скачивает видео в локальный кэш (flutter_cache_manager) и открывает как
  // файл. Повторные открытия той же карточки читают с диска без сетевых запросов.
  Future<void> _initVideo(String url) async {
    VideoPlayerController? ctrl;
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      // Ручной loop: нативный setLooping(true) на iOS даёт чёрный кадр ~раз в цикл.
      ctrl.setLooping(false);
      ctrl.addListener(_handleVideoTick);
      await ctrl.setVolume(0);
      if (!mounted) {
        ctrl.removeListener(_handleVideoTick);
        ctrl.dispose();
        return;
      }
      setState(() {
        _videoCtrl = ctrl;
        _videoFirstFrameReady = false; // shield до первого кадра
      });
      _ambientCtrl.stop();
      if (widget.isActive) ctrl.play();
    } catch (_) {
      ctrl?.removeListener(_handleVideoTick);
      ctrl?.dispose();
      if (mounted) {
        setState(() => _videoError = true);
        if (!_ambientCtrl.isAnimating) {
          _ambientCtrl.repeat(reverse: true);
        }
      }
    }
  }

  void _handleVideoTick() {
    final ctrl = _videoCtrl;
    if (ctrl == null || !ctrl.value.isInitialized || _loopSeekPending) return;

    final pos = ctrl.value.position;

    // Снимаем shield как только платформа отдала первый кадр (pos > 0).
    if (!_videoFirstFrameReady && pos.inMicroseconds > 0) {
      setState(() => _videoFirstFrameReady = true);
    }

    final dur = ctrl.value.duration;
    if (dur.inMilliseconds < 400) return;

    if (pos >= dur - const Duration(milliseconds: 120)) {
      _loopSeekPending = true;
      ctrl.seekTo(Duration.zero).whenComplete(() {
        _loopSeekPending = false;
        if (mounted && widget.isActive) ctrl.play();
      });
    }
  }

  @override
  void didUpdateWidget(DishVideoCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) {
        if (!_ambientCtrl.isAnimating) {
          _ambientCtrl.repeat(reverse: true);
        }
      } else {
        _ambientCtrl.stop();
      }
      _videoCtrl?.play();
    } else if (!widget.isActive && old.isActive) {
      _ambientCtrl.stop();
      _videoCtrl?.pause();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_handleVideoTick);
    _ambientCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Widget _buildCinematicBg() {
    return AnimatedBuilder(
      animation: _ambientCtrl,
      builder: (_, __) {
        final t = _ambientCtrl.value;
        final glow = 0.6 +
            0.25 * math.sin(t * math.pi * 1.7) +
            0.15 * math.sin(t * math.pi * 3.3);
        return DishCinematicBackground(
          colors: kDishCinematicFallbackColors,
          breathValue: t,
          glowValue: glow,
        );
      },
    );
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _videoCtrl?.setVolume(_isMuted ? 0 : 1);
  }

  void _handleDragEnd(DragEndDetails d) {
    if (d.velocity.pixelsPerSecond.dx < -300) {
      widget.onSwipeRight?.call();
      _showDishDetail();
    }
  }

  void _showDishDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DishDetailSheet(dish: widget.dish),
    );
  }

  Widget _buildMediaLayer(bool videoReady) {
    if (videoReady) {
      final size = _videoCtrl!.value.size;
      return Positioned.fill(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_videoCtrl!),
                  ),
                ),
              ),
            ),
            // Shield: закрывает чёрный кадр платформенной текстуры пока
            // декодер не выдал первый кадр (init) и во время seekTo (loop).
            if (!_videoFirstFrameReady)
              const IgnorePointer(
                child: ColoredBox(color: PiligrimColors.earthDeep),
              ),
          ],
        ),
      );
    }

    if (_videoError &&
        widget.dish.imageUrl != null &&
        widget.dish.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.dish.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _buildCinematicBg(),
        errorWidget: (_, __, ___) => _buildCinematicBg(),
      );
    }

    return _buildCinematicBg();
  }

  Widget _buildBottomInfoText(double bottomInset) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Padding(4) даёт место для text shadows на Android —
            // без него тени обрезаются клипом родителя.
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                widget.dish.name,
                style: TextStyle(
                  fontFamily: 'MuseoSans',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: PiligrimColors.nomadCream,
                  letterSpacing: 0.4,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 1),
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 32,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.dish.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  widget.dish.description.replaceAll('\n', ' '),
                  style: TextStyle(
                    fontFamily: 'MuseoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: PiligrimColors.sky.withValues(alpha: 0.75),
                    height: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.42),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DishCardPriceTag(price: widget.dish.price),
                const SizedBox(width: 14),
                Text(
                  widget.dish.weight.contains('г')
                      ? widget.dish.weight
                      : '${widget.dish.weight} г',
                  style: TextStyle(
                    fontFamily: 'MuseoSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: PiligrimColors.sky.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoReady = _videoCtrl != null && _videoCtrl!.value.isInitialized;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return GestureDetector(
      onTap: _showDishDetail,
      onHorizontalDragEnd: _handleDragEnd,
      child: ColoredBox(
        color: PiligrimColors.earthDeep,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaLayer(videoReady),

            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: PiligrimSpacing.menuFeedVideoCardGradient,
                ),
              ),
            ),

            _buildBottomInfoText(bottomInset),

            Positioned(
              top: PiligrimSpacing.menuFeedCategoryBadgeTop(context),
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VideoCategoryBadge(categoryId: widget.dish.category),
                  if (videoReady) ...[
                    const SizedBox(
                      height: PiligrimSpacing.menuFeedCategoryToMuteGap,
                    ),
                    _MuteButton(isMuted: _isMuted, onToggle: _toggleMute),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill-badge категории на видео-карточке.
// ─────────────────────────────────────────────────────────────────────────────
class _VideoCategoryBadge extends StatelessWidget {
  const _VideoCategoryBadge({required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final name = context.select<MenuProvider, String?>((p) {
      for (final c in p.categories) {
        if (c.id == categoryId) return c.name;
      }
      return null;
    });
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PiligrimColors.water.withValues(alpha: 0.4),
          width: 0.7,
        ),
      ),
      child: Text(
        name.toUpperCase(),
        style: PiligrimTextStyles.micro.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.92),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onToggle});

  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const visual = PiligrimSpacing.menuFeedMuteSize;
    const tap = PiligrimSpacing.menuFeedMuteTapExtent;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tap,
        height: tap,
        child: Center(
          child: Container(
            width: visual,
            height: visual,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: PiligrimSpacing.menuFeedMuteBackgroundOpacity,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 0.5,
              ),
            ),
            child: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white.withValues(alpha: 0.82),
              size: PiligrimSpacing.menuFeedMuteIconSize,
            ),
          ),
        ),
      ),
    );
  }
}
