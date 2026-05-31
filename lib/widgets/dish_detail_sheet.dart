// Bottom sheet детали блюда — единый экран для фото- и видео-ленты.
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../data/models/api_dish.dart';
import 'dish_elements.dart';

// Дефолтные цвета кинематографического фона (лента / sheet fallback).
const kDishCinematicFallbackColors = [
  PiligrimColors.earthDeep,
  PiligrimColors.glowAmber,
  PiligrimColors.earthDeep,
];

String formatDishPrice(int price) =>
    price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );

String dishWeightLabel(String weight) =>
    weight.contains('г') ? weight : '$weight г';


// ── Cinematic fallback (лента) ──
// ─────────────────────────────────────────────────────────────────────────────
// Кинематографический фон — используется в видео-карточке как fallback.
// ─────────────────────────────────────────────────────────────────────────────
class DishCinematicBackground extends StatelessWidget {
  const DishCinematicBackground({
    super.key,
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
      painter: _DishCinemaPainter(
        colors: colors,
        breathValue: breathValue,
        glowValue: glowValue,
      ),
    );
  }
}

class _DishCinemaPainter extends CustomPainter {
  const _DishCinemaPainter({
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

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = base);

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
  bool shouldRepaint(_DishCinemaPainter old) =>
      old.breathValue != breathValue || old.glowValue != glowValue;
}

class DishClassicThumbnailFallback extends StatelessWidget {
  const DishClassicThumbnailFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PiligrimColors.earthWarm,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/star_totem (1).svg',
          width: 44,
          height: 44,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.18),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DishDetailSheet — единый экран блюда (фото-лента и видео-лента).
// ─────────────────────────────────────────────────────────────────────────────
class DishDetailSheet extends StatelessWidget {
  const DishDetailSheet({super.key, required this.dish});
  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    final safeMax = screenH > 0
        ? ((screenH - topInset - 8) / screenH).clamp(0.88, 0.94)
        : 0.90;
    // Hero занимает ~52% высоты sheet — cinematic moment при открытии.
    final heroH = screenH * 0.88 * 0.52;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: safeMax,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Hero ─────────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                height: heroH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    dish.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: dish.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const DishClassicThumbnailFallback(),

                    // Cinematic warm tint.
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x1A200C04)),
                    ),

                    // Верхний виньет — handle readability.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x35000000), Colors.transparent],
                          stops: [0.0, 0.35],
                        ),
                      ),
                    ),

                    // Нижний градиент — плавный переход в earthDeep.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            PiligrimColors.earthDeep.withValues(alpha: 0.0),
                            PiligrimColors.earthDeep.withValues(alpha: 0.0),
                            PiligrimColors.earthDeep.withValues(alpha: 0.68),
                            PiligrimColors.earthDeep,
                          ],
                          stops: const [0.0, 0.46, 0.76, 1.0],
                        ),
                      ),
                    ),

                    // Handle
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PiligrimColors.sky.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // Название + Цена · Вес — единый информационный блок.
                    Positioned(
                      left: 24,
                      right: 16,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dish.name,
                            style: PiligrimTextStyles.display.copyWith(
                              fontSize: 26,
                              color: PiligrimColors.nomadCream,
                              letterSpacing: 0.1,
                              height: 1.18,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${formatDishPrice(dish.price)} ₸',
                                style: const TextStyle(
                                  fontFamily: PiligrimFonts.museoSans,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: PiligrimColors.steppe,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (dish.weight.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 7),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      fontFamily: PiligrimFonts.museoSans,
                                      fontSize: 14,
                                      color: PiligrimColors.sky.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                Text(
                                  dishWeightLabel(dish.weight),
                                  style: TextStyle(
                                    fontFamily: PiligrimFonts.museoSans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                    color: PiligrimColors.sky.withValues(alpha: 0.55),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 16),
                children: [
                  if (dish.description.isNotEmpty)
                    Text(
                      dish.description.replaceAll('\n', ' '),
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.78),
                        fontSize: 14,
                        height: 1.72,
                      ),
                    ),

                  if (dish.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DishDetailTagsRow(tags: dish.tags),
                  ],

                  if (dish.story.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _DishStoryBlock(story: dish.story),
                  ],

                  if (dish.allergens.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _DishAllergensBlock(allergens: dish.allergens),
                  ],

                  const _DishAtmosphericBottom(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ClassicDishDetailSheet — алиас единого DishDetailSheet.
// Фото-лента и видео-лента используют один и тот же экран.
class ClassicDishDetailSheet extends DishDetailSheet {
  const ClassicDishDetailSheet({super.key, required super.dish});
}

// ── Атмосферное завершение экрана ────────────────────────────────────────────
// Тонкая fade-линия + spiral-орнамент + тёплый нижний свет.
// Исключает тяжёлый чёрный обрыв после последнего блока контента.
// ─────────────────────────────────────────────────────────────────────────────
class _DishAtmosphericBottom extends StatelessWidget {
  const _DishAtmosphericBottom();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            PiligrimColors.ember.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  PiligrimColors.steppe.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.14),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── История — cinematic left-accent block ────────────────────────────────────
class _DishStoryBlock extends StatelessWidget {
  const _DishStoryBlock({required this.story});
  final String story;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: PiligrimColors.steppe.withValues(alpha: 0.42),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/spiral.svg',
                width: 10,
                height: 10,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.steppe.withValues(alpha: 0.60),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'ИСТОРИЯ',
                style: PiligrimTextStyles.sectionLabel.copyWith(
                  color: PiligrimColors.steppe.withValues(alpha: 0.65),
                  letterSpacing: 2.2,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            story,
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.steppe.withValues(alpha: 0.80),
              fontSize: 14,
              height: 1.72,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Аллергены — pill-чипы с water-тинтом ─────────────────────────────────────
class _DishAllergensBlock extends StatelessWidget {
  const _DishAllergensBlock({required this.allergens});
  final List<String> allergens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PiligrimColors.steppe.withValues(alpha: 0.22),
                PiligrimColors.steppe.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        Text('АЛЛЕРГЕНЫ', style: PiligrimTextStyles.sectionLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: allergens.map((allergen) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: PiligrimColors.water.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PiligrimColors.water.withValues(alpha: 0.25),
                width: 0.7,
              ),
            ),
            child: Text(
              allergen,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: PiligrimColors.sky.withValues(alpha: 0.60),
                letterSpacing: 0.3,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
