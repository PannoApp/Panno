// Bottom sheets детали блюда: cinematic (лента) и classic (каталог).
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
// Кинематографический фон (используется как fallback когда нет видео)
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

class DishDetailSheet extends StatelessWidget {
  const DishDetailSheet({super.key, required this.dish});
  final ApiDish dish;

  String get _formattedPrice => '${formatDishPrice(dish.price)} ₸';

  String get _weightLabel => dishWeightLabel(dish.weight);

  @override
  Widget build(BuildContext context) {
    const fallbackBg = DishCinematicBackground(
      colors: kDishCinematicFallbackColors,
      breathValue: 0.5,
      glowValue: 0.8,
    );

    final topInset = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    // Ensure the sheet top never reaches into the Dynamic Island / notch zone.
    // 8pt buffer so the rounded corner sits visibly below the system bar.
    final safeMax = screenH > 0
        ? ((screenH - topInset - 8) / screenH).clamp(0.88, 0.94)
        : 0.90;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: safeMax,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Изображение заполняет сверху; handle и бейджи наложены поверх
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: dish.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => fallbackBg,
                                errorWidget: (_, __, ___) => fallbackBg,
                              )
                            : fallbackBg,
                        // Градиент снизу для читаемости бейджей
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  PiligrimColors.shadow.withValues(alpha: 0.75),
                                  PiligrimColors.clear,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Handle — поверх фото, как в ClassicDishDetailSheet
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 38,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: PiligrimColors.sky.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
                // Бейджи цены и веса
                Positioned(
                  bottom: 14,
                  left: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DishDetailImageBadge(text: _formattedPrice, bordered: true),
                      const SizedBox(width: 8),
                      _DishDetailImageBadge(text: _weightLabel),
                    ],
                  ),
                ),
              ],
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
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: PiligrimColors.divider, height: 1),
                  ),

                  // Описание — без заголовка секции
                  if (dish.description.isNotEmpty)
                    Text(
                      dish.description.replaceAll('\n', ' '),
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),

                  if (dish.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DishDetailTagsRow(tags: dish.tags),
                  ],

                  if (dish.story.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    DishDetailSection(
                      title: 'История',
                      icon: 'assets/images/cobyz.svg',
                      content: dish.story,
                      accent: true,
                    ),
                  ],

                  if (dish.allergens.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DishDetailSection(
                      title: 'Аллергены',
                      icon: 'assets/images/luk.svg',
                      content: dish.allergens.join(' · '),
                    ),
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

// Бейдж поверх изображения (цена — с рамкой, вес — без)
class _DishDetailImageBadge extends StatelessWidget {
  const _DishDetailImageBadge({required this.text, this.bordered = false});

  final String text;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bordered
            ? PiligrimColors.imageScrim.withValues(alpha: 0.84)
            : PiligrimColors.shadow.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(7),
        border: bordered
            ? Border.all(
                color: PiligrimColors.steppe.withValues(alpha: 0.58),
                width: 0.9,
              )
            : null,
        boxShadow: bordered
            ? [
                BoxShadow(
                  color: PiligrimColors.steppe.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'MuseoSans',
          fontSize: bordered ? 14 : 13,
          fontWeight: bordered ? FontWeight.w700 : FontWeight.w300,
          color: bordered ? PiligrimColors.steppe : PiligrimColors.sky,
        ),
      ),
    );
  }
}

class ClassicDishDetailSheet extends StatelessWidget {
  const ClassicDishDetailSheet({super.key, required this.dish});
  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    final topInset = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    final safeMax = screenH > 0
        ? ((screenH - topInset - 8) / screenH).clamp(0.88, 0.94)
        : 0.90;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: safeMax,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earth,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // [1] Фото — 4:3 hero-образ
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: dish.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: dish.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const DishClassicThumbnailFallback(),
                  ),
                ),
                // Верхний виньет — тонирует яркие фото, делает handle читаемым.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          PiligrimColors.imageScrim.withValues(alpha: 0.44),
                          PiligrimColors.clear,
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                  ),
                ),
                // Многоступенчатый bottom gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          PiligrimColors.clear,
                          PiligrimColors.imageScrim.withValues(alpha: 0.27),
                          PiligrimColors.imageScrim.withValues(alpha: 0.82),
                          PiligrimColors.imageScrim.withValues(alpha: 0.96),
                        ],
                        stops: const [0.0, 0.38, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
                // Handle — чуть крупнее, sky-тинт для читаемости на тёмном.
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
                // Цена + вес — pills внизу слева
                Positioned(
                  bottom: 16,
                  left: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Цена — ember-glow как в классической карточке.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: PiligrimColors.imageScrim.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.58),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: PiligrimColors.steppe.withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          '${formatDishPrice(dish.price)} ₸',
                          style: const TextStyle(
                            fontFamily: PiligrimFonts.museoSans,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: PiligrimColors.steppe,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Вес — вторичный pill
                      if (dish.weight.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: PiligrimColors.earthDeep.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: PiligrimColors.divider,
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            '${dish.weight} г',
                            style: PiligrimTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: PiligrimColors.sky.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // [2] Контент
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 48),
                children: [
                  // Название
                  Text(
                    dish.name,
                    style: PiligrimTextStyles.title.copyWith(
                      fontSize: 24,
                      color: PiligrimColors.nomadCream,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // steppe-hairline разделитель
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          PiligrimColors.steppe.withValues(alpha: 0.35),
                          PiligrimColors.steppe.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Описание
                  Text(
                    dish.description.replaceAll('\n', ' '),
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.78),
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),

                  if (dish.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DishDetailTagsRow(tags: dish.tags),
                  ],

                  // История
                  if (dish.story.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/images/spiral.svg',
                          width: 10,
                          height: 10,
                          colorFilter: ColorFilter.mode(
                            PiligrimColors.steppe.withValues(alpha: 0.5),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('ИСТОРИЯ', style: PiligrimTextStyles.sectionLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dish.story,
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.steppe.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Аллергены — полные pill-чипы, water-тинт для лёгкого акцента.
                  if (dish.allergens.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    // steppe-hairline перед секцией (единый штрих с другими разделителями)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PiligrimColors.steppe.withValues(alpha: 0.25),
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
                      children: dish.allergens.map((allergen) {
                        return Container(
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
                              color: PiligrimColors.sky.withValues(alpha: 0.6),
                              letterSpacing: 0.3,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
