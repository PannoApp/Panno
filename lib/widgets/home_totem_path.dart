// Горизонтальное меню «Путь Героя» — тотемы, воздух, явный выбранный шаг
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import '../providers/menu_provider.dart';
import 'piligrim_tap.dart';

class HomeTotemPathRow extends StatefulWidget {
  const HomeTotemPathRow({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  State<HomeTotemPathRow> createState() => _HomeTotemPathRowState();
}

class _HomeTotemPathRowState extends State<HomeTotemPathRow> {
  int _selected = 0;

  Future<void> _onItemTap(int index) async {
    setState(() => _selected = index);
    final cat = kMenuCategories[index];

    if (cat.navIndex == 1 && cat.menuCategoryNameHint != null) {
      await context.read<MenuProvider>().openMenuPathCategory(
            cat.menuCategoryNameHint!,
          );
      if (!mounted) return;
      widget.onNavigate?.call(1);
      return;
    }

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
          height: 132,
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? PiligrimColors.sky.withValues(alpha: 0.03)
                        : PiligrimColors.clear,
                    border: Border.all(
                      width: selected ? 0.65 : 0.5,
                      color: selected
                          ? cat.accentColor.withValues(alpha: 0.22)
                          : PiligrimColors.sky.withValues(alpha: 0.055),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: cat.accentColor.withValues(alpha: 0.10),
                              blurRadius: 18,
                              spreadRadius: -6,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: SvgPicture.asset(
                          cat.totemAsset,
                          width: 24,
                          height: 24,
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
                          fontSize: 10.25,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w300,
                          letterSpacing: selected ? 1.55 : 1.35,
                          height: 1.32,
                          color: selected
                              ? PiligrimColors.sky.withValues(alpha: 0.96)
                              : PiligrimColors.sky.withValues(alpha: 0.82),
                        ),
                        child: Text(
                          cat.titleRu.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: PiligrimTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          height: 1.34,
                          letterSpacing: 0.15,
                          color: PiligrimColors.sky.withValues(
                            alpha: selected ? 0.62 : 0.52,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: Column(
            children: [
              for (var i = 0; i < kHeroPathFooterActions.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _HeroPathFooterRow(
                  action: kHeroPathFooterActions[i],
                  onNavigate: widget.onNavigate,
                  delay: Duration(milliseconds: 280 + 70 * i),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPathFooterRow extends StatelessWidget {
  const _HeroPathFooterRow({
    required this.action,
    required this.onNavigate,
    required this.delay,
  });

  final HeroPathFooterAction action;
  final ValueChanged<int>? onNavigate;
  final Duration delay;

  Future<void> _onTap(BuildContext context) async {
    if (action.openMenuBrowseAll) {
      await context.read<MenuProvider>().openMenuBrowseAll();
      if (!context.mounted) return;
      onNavigate?.call(action.tabIndex);
      return;
    }
    onNavigate?.call(action.tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      scaleDown: 0.98,
      onTap: () => _onTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SvgPicture.asset(
              action.totemAsset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                PiligrimColors.water.withValues(alpha: 0.72),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                action.label,
                style: PiligrimTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: PiligrimColors.sky.withValues(alpha: 0.82),
                  letterSpacing: 0.25,
                  height: 1.25,
                ),
              ),
            ),
            Text(
              '→',
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 13,
                color: PiligrimColors.sky.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 480.ms, curve: Curves.easeOut);
  }
}
