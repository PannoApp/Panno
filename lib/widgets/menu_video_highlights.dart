// Горизонтальная полоса превью видео-блюд в классическом меню.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import '../data/models/api_dish.dart';
import 'piligrim_tap.dart';

/// «Путь вкуса» — карточки 9:16 с переходом в видео-ленту.
class MenuVideoHighlights extends StatelessWidget {
  const MenuVideoHighlights({
    super.key,
    required this.dishes,
    required this.onDishTap,
  });

  final List<ApiDish> dishes;
  final ValueChanged<ApiDish> onDishTap;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/star_totem (1).svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.steppe.withValues(alpha: 0.55),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ПУТЬ ВКУСА',
                style: PiligrimTextStyles.sectionLabel.copyWith(
                  color: PiligrimColors.steppe.withValues(alpha: 0.75),
                  letterSpacing: 2.2,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
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
              ),
            ],
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: dishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _HighlightCard(
              dish: dishes[i],
              onTap: () => onDishTap(dishes[i]),
            )
                .animate(delay: Duration(milliseconds: i * 60))
                .fadeIn(duration: 420.ms)
                .slideX(begin: 0.06, end: 0, duration: 420.ms, curve: Curves.easeOut),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.dish, required this.onTap});

  final ApiDish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (dish.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: dish.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _HighlightPlaceholder(),
                        errorWidget: (_, __, ___) => const _HighlightPlaceholder(),
                      )
                    else
                      const _HighlightPlaceholder(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x301C1510),
                            Color(0x881C1510),
                            Color(0xE61C1510),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.65),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: PiligrimColors.steppe.withValues(alpha: 0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: PiligrimColors.steppe.withValues(alpha: 0.92),
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dish.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: PiligrimColors.nomadCream.withValues(alpha: 0.82),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightPlaceholder extends StatelessWidget {
  const _HighlightPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PiligrimColors.earthWarm,
            PiligrimColors.earthDeep.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/star_totem (1).svg',
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.2),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
