// DishVideoCard — полноэкранная карточка в стиле Reels / TikTok
// «Каждое блюдо — отдельное приключение» (brandbook, стр. 17)
// Блок 5: переключение на ApiDish, VideoPlayerController при наличии videoUrl.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../core/theme.dart';
import '../data/models/api_dish.dart';
import 'dish_elements.dart';

// Дефолтные цвета кинематографического фона (используются когда нет видео и нет imageUrl)
const _kDefaultCinematicColors = [
  Color(0xFF1A0E08),
  Color(0xFF2E1A10),
  Color(0xFF1A0E08),
];

// Дефолтный тотем на карточке (если у блюда нет категории в локальных данных)
const _kDefaultTotem = 'assets/images/bird_totem (1).svg';

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

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Инициализируем видео только если у блюда есть ссылка
    if (widget.dish.videoUrl != null) {
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
      builder: (_) => _DishDetailSheet(dish: widget.dish),
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
            // ── 1. Видео на весь экран ────────────────────────────
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
            else
              AnimatedBuilder(
                animation: _ambientCtrl,
                builder: (_, __) {
                  final t = _ambientCtrl.value;
                  final glow = 0.6 +
                      0.25 * math.sin(t * math.pi * 1.7) +
                      0.15 * math.sin(t * math.pi * 3.3);
                  return _CinematicBackground(
                    colors: _kDefaultCinematicColors,
                    breathValue: t,
                    glowValue: glow,
                  );
                },
              ),

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

            // ── 4. Нижний градиент — плавный переход в earthDeep ─
            const Positioned(
              bottom: 0, left: 0, right: 0,
              height: 340,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.4, 0.72, 1.0],
                    colors: [
                      Colors.transparent,
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
                        DishInfoChip(
                          label: widget.dish.weight,
                          icon: 'assets/images/stone.svg',
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

            // ── 6. Кнопка звука ───────────────────────────────────
            if (videoReady)
              Positioned(
                top: topInset + 58,
                right: 20,
                child: _MuteButton(isMuted: _isMuted, onToggle: _toggleMute),
              ),

            // ── 7. Хинт свайпа ────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Кинематографический фон (используется как fallback когда нет видео)
// ─────────────────────────────────────────────────────────────────────────────
class _CinematicBackground extends StatelessWidget {
  const _CinematicBackground({
    required this.colors,
    required this.breathValue,
    required this.glowValue,
  });

  final List<Color> colors;
  final double breathValue;
  final double glowValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CinemaPainter(
        colors: colors,
        breathValue: breathValue,
        glowValue: glowValue,
      ),
    );
  }
}

class _CinemaPainter extends CustomPainter {
  const _CinemaPainter({
    required this.colors,
    required this.breathValue,
    required this.glowValue,
  });

  final List<Color> colors;
  final double breathValue;
  final double glowValue;

  @override
  void paint(Canvas canvas, Size size) {
    final base = colors.isNotEmpty ? colors[0] : PiligrimColors.earthDeep;
    final mid = colors.length > 1 ? colors[1] : base;
    final accent = colors.length > 2 ? colors[2] : mid;

    // Base fill
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = base);

    // Animated warm radial light (simulates video glow)
    final shader = RadialGradient(
      center: Alignment(
        -0.4 + breathValue * 0.3,
        -0.2 + breathValue * 0.15,
      ),
      radius: 1.0,
      colors: [
        accent.withValues(alpha: 0.55 + glowValue * 0.2),
        mid.withValues(alpha: 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = shader);

    // Fine grain noise
    final rng = math.Random(42);
    final noisePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 600; i++) {
      noisePaint.color =
          Colors.white.withValues(alpha: rng.nextDouble() * 0.015);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.8,
        noisePaint,
      );
    }

    // Warm bottom glow
    final bottomShader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        PiligrimColors.ember.withValues(alpha: 0.08 + glowValue * 0.05),
        Colors.transparent,
      ],
      stops: const [0, 0.4],
    ).createShader(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      Paint()..shader = bottomShader,
    );
  }

  @override
  bool shouldRepaint(_CinemaPainter old) =>
      old.breathValue != breathValue || old.glowValue != glowValue;
}


// ─────────────────────────────────────────────────────────────────────────────
// DishDetailSheet — полная карточка блюда (bottom sheet)
// «Получение знания» (design spec раздел 9)
// ─────────────────────────────────────────────────────────────────────────────
class _DishDetailSheet extends StatelessWidget {
  const _DishDetailSheet({required this.dish});
  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    // Статичный cinematic-фон для превью в детальном листе
    const fallbackBg = _CinematicBackground(
      colors: _kDefaultCinematicColors,
      breathValue: 0.5,
      glowValue: 0.8,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 38,
              height: 3,
              decoration: BoxDecoration(
                color: PiligrimColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Превью блюда: сетевое изображение или cinematic gradient
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    DishThumbnail(
                      imageUrl: dish.imageUrl,
                      fallback: fallbackBg,
                    ),
                    // Декоративный тотем поверх превью
                    Positioned.fill(
                      child: Center(
                        child: SvgPicture.asset(
                          _kDefaultTotem,
                          width: 80,
                          height: 80,
                          colorFilter: ColorFilter.mode(
                            Colors.white.withValues(alpha: 0.12),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Контент
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  // Название блюда
                  Text(
                    dish.name,
                    style: PiligrimTextStyles.title.copyWith(
                      color: PiligrimColors.sky,
                      fontSize: 22,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Вес + цена
                  Row(
                    children: [
                      DishInfoChip(
                        label: dish.weight,
                        icon: 'assets/images/stone.svg',
                      ),
                      const SizedBox(width: 8),
                      DishInfoChip(
                        label: '${dish.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
                        icon: 'assets/images/zerno.svg',
                        accent: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Теги
                  if (dish.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: dish.tags.map((t) => DishCardTagChip(tag: t)).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Описание
                  DishDetailSection(
                    title: 'О блюде',
                    icon: 'assets/images/spiral.svg',
                    content: dish.description.replaceAll('\n', ' '),
                  ),

                  const SizedBox(height: 16),

                  // История блюда
                  DishDetailSection(
                    title: 'История',
                    icon: 'assets/images/cobyz.svg',
                    content: dish.story,
                    accent: true,
                  ),

                  const SizedBox(height: 16),

                  // Аллергены
                  if (dish.allergens.isNotEmpty)
                    DishDetailSection(
                      title: 'Аллергены',
                      icon: 'assets/images/luk.svg',
                      content: dish.allergens.join(' · '),
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
