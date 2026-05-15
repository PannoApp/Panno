// Горизонтальное меню «Путь Героя» — тотемы, воздух, явный выбранный шаг
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import 'piligrim_tap.dart';

class HomeTotemPathRow extends StatefulWidget {
  const HomeTotemPathRow({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  State<HomeTotemPathRow> createState() => _HomeTotemPathRowState();
}

class _HomeTotemPathRowState extends State<HomeTotemPathRow> {
  int _selected = 0;

  void _onItemTap(int index) {
    setState(() => _selected = index);
    final cat = kMenuCategories[index];
    widget.onNavigate?.call(cat.navIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 0.5,
                color: PiligrimColors.sky.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 28),
              Text(
                'ПУТЬ ГЕРОЯ',
                style: PiligrimTextStyles.sectionLabel.copyWith(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: PiligrimColors.sky.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Куда ведёт следующий шаг',
                style: PiligrimTextStyles.bodySmall.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  letterSpacing: 0.25,
                  color: PiligrimColors.sky.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 520.ms, curve: Curves.easeOut),
        const SizedBox(height: 24),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            itemCount: kMenuCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final cat = kMenuCategories[i];
              final selected = i == _selected;
              return PiligrimTap(
                scaleDown: 0.96,
                releaseDuration: const Duration(milliseconds: 300),
                onTap: () => _onItemTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: 118,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? PiligrimColors.sky.withValues(alpha: 0.048)
                        : PiligrimColors.clear,
                    border: Border.all(
                      width: selected ? 1.2 : 1,
                      color: selected
                          ? cat.accentColor.withValues(alpha: 0.42)
                          : PiligrimColors.sky.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: SvgPicture.asset(
                          cat.totemAsset,
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            selected
                                ? cat.accentColor
                                : PiligrimColors.sky.withValues(alpha: 0.58),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        style: PiligrimTextStyles.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w300,
                          letterSpacing: selected ? 1.65 : 1.35,
                          height: 1.22,
                          color: selected
                              ? PiligrimColors.sky.withValues(alpha: 0.96)
                              : PiligrimColors.sky.withValues(alpha: 0.74),
                        ),
                        child: Text(
                          cat.titleRu.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cat.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: PiligrimTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w300,
                          height: 1.22,
                          letterSpacing: 0.12,
                          color: PiligrimColors.sky.withValues(
                            alpha: selected ? 0.58 : 0.46,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: Duration(milliseconds: 70 + 85 * i))
                  .fadeIn(duration: 640.ms, curve: Curves.easeOut);
            },
          ),
        ),
      ],
    );
  }
}
