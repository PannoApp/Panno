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
import 'piligrim_tap.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PiligrimColors.steppe.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
        style: PiligrimTextStyles.button.copyWith(
          color: PiligrimColors.steppe,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class DishCardActionBar extends StatefulWidget {
  const DishCardActionBar({super.key, required this.dish});
  final ApiDish dish;

  @override
  State<DishCardActionBar> createState() => _DishCardActionBarState();
}

class _DishCardActionBarState extends State<DishCardActionBar> {
  bool _liked = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DishActionBtn(
          asset: 'assets/images/star_totem (1).svg',
          label: _liked ? 'В пути' : 'Нравится',
          active: _liked,
          color: PiligrimColors.steppe,
          onTap: () => setState(() => _liked = !_liked),
        ),
        const SizedBox(height: 22),
        _DishActionBtn(
          asset: 'assets/images/moon_totem (1).svg',
          label: _saved ? 'Сохранено' : 'Запомнить',
          active: _saved,
          color: PiligrimColors.water,
          onTap: () => setState(() => _saved = !_saved),
        ),
        const SizedBox(height: 22),
        _DishActionBtn(
          asset: 'assets/images/luk.svg',
          label: 'Поделиться',
          active: false,
          color: PiligrimColors.sky,
          onTap: () {},
        ),
      ],
    );
  }
}

class _DishActionBtn extends StatelessWidget {
  const _DishActionBtn({
    required this.asset,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? color.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.3),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: SvgPicture.asset(
              asset,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                active ? color : PiligrimColors.sky.withValues(alpha: 0.7),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PiligrimTextStyles.caption.copyWith(
              fontSize: 9.5,
              color: active ? color : PiligrimColors.sky.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class DishCardSwipeHint extends StatelessWidget {
  const DishCardSwipeHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/spiral.svg',
          width: 12,
          height: 12,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.7),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Свайп вправо — история блюда',
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.55),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          size: 14,
          color: PiligrimColors.steppe.withValues(alpha: 0.7),
        ),
      ],
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
    this.height = 180,
  });

  final String? imageUrl;
  final Widget fallback;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return SizedBox(height: height, child: fallback);

    return SizedBox(
      height: height,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        // При загрузке и при ошибке показываем кинематографический фон
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class DishBookingCta extends StatelessWidget {
  const DishBookingCta({super.key, required this.dish});
  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PiligrimColors.steppe, PiligrimColors.emberDeep],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.ember.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: PiligrimTap(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            'ЗАКАЗАТЬ ЗА ${dish.price} ₸',
            style: PiligrimTextStyles.button.copyWith(
              color: PiligrimColors.sky,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
