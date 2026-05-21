// Горизонтальное меню «Путь Героя» — тотемы, воздух, явный выбранный шаг
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import '../providers/menu_provider.dart';
import 'piligrim_tap.dart';

/// Общая рамка узла пути (карточка этапа или камень продолжения).
BoxDecoration _pathNodeDecoration({
  required bool emphasized,
  required Color accentColor,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: emphasized
        ? PiligrimColors.sky.withValues(alpha: 0.055)
        : PiligrimColors.clear,
    border: Border.all(
      width: emphasized ? 0.75 : 0.5,
      color: emphasized
          ? accentColor.withValues(alpha: 0.38)
          : PiligrimColors.sky.withValues(alpha: 0.055),
    ),
    boxShadow: emphasized
        ? [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.14),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 5),
            ),
          ]
        : null,
  );
}

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  decoration: _pathNodeDecoration(
                    emphasized: selected,
                    accentColor: cat.accentColor,
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
          padding: const EdgeInsets.fromLTRB(36, 22, 36, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HeroPathTrail(),
              const SizedBox(height: 18),
              Text(
                'ДАЛЬШЕ ПО ПУТИ',
                style: PiligrimTextStyles.sectionLabel.copyWith(
                  fontSize: 9,
                  letterSpacing: 2.2,
                  color: PiligrimColors.sky.withValues(alpha: 0.38),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < kHeroPathFooterActions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _HeroPathWaystone(
                        action: kHeroPathFooterActions[i],
                        onNavigate: widget.onNavigate,
                        delay: Duration(milliseconds: 300 + 80 * i),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 520.ms, curve: Curves.easeOut),
      ],
    );
  }
}

/// Нить между этапами и продолжением пути.
class _HeroPathTrail extends StatelessWidget {
  const _HeroPathTrail();

  @override
  Widget build(BuildContext context) {
    final line = PiligrimColors.sky.withValues(alpha: 0.10);
    final node = PiligrimColors.water.withValues(alpha: 0.35);

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 0.5,
                height: 14,
                color: line,
              ),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: node, width: 0.75),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      line,
                      PiligrimColors.water.withValues(alpha: 0.22),
                      PiligrimColors.steppe.withValues(alpha: 0.18),
                      line,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(bottom: 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PiligrimColors.steppe.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPathWaystone extends StatelessWidget {
  const _HeroPathWaystone({
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
      scaleDown: 0.97,
      releaseDuration: const Duration(milliseconds: 280),
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        decoration: _pathNodeDecoration(
          emphasized: false,
          accentColor: action.accentColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              action.totemAsset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                action.accentColor.withValues(alpha: 0.88),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              action.label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.35,
                height: 1.3,
                color: PiligrimColors.sky.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              action.subtitle,
              textAlign: TextAlign.center,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                height: 1.3,
                letterSpacing: 0.15,
                color: PiligrimColors.sky.withValues(alpha: 0.48),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }
}
