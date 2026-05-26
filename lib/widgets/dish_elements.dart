// Переиспользуемые виджеты карточки блюда.
// Перенесён с локальной модели Dish на ApiDish (блок 5).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/menu_data.dart';
import '../core/theme.dart';
import '../data/models/api_dish.dart';
import '../data/models/api_tag.dart';
import 'piligrim_info_section.dart';
import 'piligrim_shimmer.dart';

/// Нижний информационный блок для Reel-карточки блюда.
class DishCardBottomInfo extends StatelessWidget {
  const DishCardBottomInfo({super.key, required this.dish});

  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 80, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dish.name,
            style: PiligrimTextStyles.display.copyWith(
              fontSize: 28,
              height: 1.15,
              color: PiligrimColors.sky,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 550.ms).slideY(
                begin: 0.08,
                end: 0,
                duration: 550.ms,
              ),
          const SizedBox(height: 10),
          Text(
            dish.description,
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 14,
              color: PiligrimColors.sky.withValues(alpha: 0.65),
              height: 1.55,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 280.ms, duration: 500.ms),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: dish.tags.map((tag) => DishCardTagChip(tag: tag)).toList(),
                ),
              ),
              const SizedBox(width: 12),
              DishCardPriceTag(price: dish.price),
            ],
          ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

/// Спокойная typographic-строка тегов для detail sheet (без capsules/chips).
class DishTagMetadataLine extends StatelessWidget {
  const DishTagMetadataLine({super.key, required this.tags});

  final List<ApiTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final line = tags.map((t) => t.name.trim().toLowerCase()).join(' · ');

    return Text(
      line,
      style: PiligrimTextStyles.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.8,
        height: 1.45,
        color: PiligrimColors.sky.withValues(alpha: 0.40),
      ),
    );
  }
}

/// Чип тега блюда с иконкой и цветом.
/// Принимает ApiTag из API; стиль подбирается по имени из реестра в menu_data.dart.
/// Неизвестные теги отображаются с дефолтным стилем без обновления приложения.
class DishCardTagChip extends StatelessWidget {
  const DishCardTagChip({super.key, required this.tag});

  final ApiTag tag;

  @override
  Widget build(BuildContext context) {
    final style = tagStyleFor(tag.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: style.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            style.iconAsset,
            width: 11,
            height: 11,
            colorFilter: ColorFilter.mode(style.color, BlendMode.srcIn),
          ),
          const SizedBox(width: 4),
          Text(
            tag.name,
            style: PiligrimTextStyles.caption.copyWith(
              color: style.color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class DishCardPriceTag extends StatelessWidget {
  const DishCardPriceTag({super.key, required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD61C1510),
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
          BoxShadow(
            color: PiligrimColors.shadow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
        style: PiligrimTextStyles.button.copyWith(
          color: PiligrimColors.steppe,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class DishInfoChip extends StatelessWidget {
  const DishInfoChip({
    super.key,
    required this.label,
    required this.icon,
    this.accent = false,
  });

  final String label;
  final String icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? PiligrimColors.steppe : PiligrimColors.water;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            width: 13,
            height: 13,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: PiligrimTextStyles.caption.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// DishDetailSection — делегирует в PiligrimInfoSection (единая реализация).
class DishDetailSection extends StatelessWidget {
  const DishDetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.accent = false,
  });

  final String title;
  final String icon;
  final String content;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return PiligrimInfoSection(
      title: title,
      icon: icon,
      content: content,
      accent: accent,
    );
  }
}

/// Превью изображения блюда: сетевая картинка с fallback на cinematic-фон.
/// Используется в детальном листе блюда (bottom sheet).
class DishThumbnail extends StatelessWidget {
  const DishThumbnail({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.aspectRatio = 16 / 9,
  });

  final String? imageUrl;
  final Widget fallback;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              // При загрузке и при ошибке показываем кинематографический фон
              placeholder: (_, __) => const PiligrimShimmer(),
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

