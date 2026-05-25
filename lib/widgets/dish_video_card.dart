// DishVideoCard — полноэкранная карточка в стиле Reels / TikTok
// «Каждое блюдо — отдельное приключение» (brandbook, стр. 17)
// Блок 5: переключение на ApiDish, VideoPlayerController при наличии videoUrl.
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Запускаем видео только если оно уже обработано на сервере
    if (widget.dish.videoUrl != null && widget.dish.videoStatus == 'ready') {
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
      ctrl.setLooping(true);
      await ctrl.setVolume(0);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() => _videoCtrl = ctrl);
      if (widget.isActive) ctrl.play();
    } catch (_) {
      ctrl?.dispose();
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void didUpdateWidget(DishVideoCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ambientCtrl.repeat(reverse: true);
      _videoCtrl?.play();
    } else if (!widget.isActive && old.isActive) {
      _ambientCtrl.stop();
      _videoCtrl?.pause(); // пауза, не dispose — для быстрого возобновления
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final videoReady = _videoCtrl != null && _videoCtrl!.value.isInitialized;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return GestureDetector(
      onTap: _showDishDetail,
      onHorizontalDragEnd: _handleDragEnd,
      child: ColoredBox(
        color: PiligrimColors.earthDeep,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Видео / фото / кинематографический фон ────────
            if (videoReady)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoCtrl!.value.size.width,
                    height: _videoCtrl!.value.size.height,
                    child: VideoPlayer(_videoCtrl!),
                  ),
                ),
              )
            else if (_videoError &&
                widget.dish.imageUrl != null &&
                widget.dish.imageUrl!.isNotEmpty)
              // Видео не загрузилось — показываем статичное фото блюда
              CachedNetworkImage(
                imageUrl: widget.dish.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => _buildCinematicBg(),
                errorWidget: (_, __, ___) => _buildCinematicBg(),
              )
            else
              _buildCinematicBg(),

            // ── 2. Верхний скрим (читаемость хэдера) ─────────────
            Positioned(
              top: 0, left: 0, right: 0,
              height: topInset + 100,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── 3. Боковой виньет (кинематографичность) ──────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ── 4. Нижний градиент — многоступенчатый, без видимой «полосы» ─
            const Positioned(
              bottom: 0, left: 0, right: 0,
              height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.28, 0.55, 0.78, 1.0],
                    colors: [
                      Colors.transparent,
                      Color(0x552A2826),
                      Color(0xBB2A2826),
                      Color(0xEE2A2826),
                      Color(0xFF2A2826),
                    ],
                  ),
                ),
              ),
            ),

            // ── 5. Инфо о блюде (поверх градиента) ───────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название — крупно, это герой экрана
                    Text(
                      widget.dish.name,
                      style: const TextStyle(
                        fontFamily: 'MuseoSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: PiligrimColors.nomadCream,
                        letterSpacing: 0.4,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Краткое описание (ТЗ 4.2: «1–2 строки»)
                    if (widget.dish.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.dish.description.replaceAll('\n', ' '),
                        style: TextStyle(
                          fontFamily: 'MuseoSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: PiligrimColors.sky.withValues(alpha: 0.62),
                          height: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Цена + вес
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.dish.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
                          style: const TextStyle(
                            fontFamily: 'MuseoSans',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: PiligrimColors.ember,
                            letterSpacing: 0.6,
                          ),
                        ),
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

                    // Теги (если есть)
                    if (widget.dish.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: widget.dish.tags
                            .take(4)
                            .map((t) => DishCardTagChip(tag: t))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 6. Pill-badge категории сверху-слева (под status bar)
            Positioned(
              top: topInset + 60,
              left: 20,
              child: _VideoCategoryBadge(categoryId: widget.dish.category),
            ),

            // ── 7. Кнопка звука ───────────────────────────────────
            if (videoReady)
              Positioned(
                top: topInset + 58,
                right: 20,
                child: _MuteButton(isMuted: _isMuted, onToggle: _toggleMute),
              ),

            // ── 8. Хинт свайпа ────────────────────────────────────
            if (widget.isActive)
              Positioned(
                left: 24,
                bottom: bottomInset + 170,
                child: const DishCardSwipeHint()
                    .animate(delay: 1800.ms)
                    .fadeIn(duration: 600.ms)
                    .then(delay: 2000.ms)
                    .fadeOut(duration: 500.ms),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill-badge категории на видео-карточке.
// Имя берётся из MenuProvider по id блюда (без новых полей в модели).
// Если категорий ещё нет в провайдере — badge скрыт.
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
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка вкл/выкл звука на видео
// ─────────────────────────────────────────────────────────────────────────────
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onToggle});

  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
