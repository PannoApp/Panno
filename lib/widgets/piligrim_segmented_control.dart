import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Единый water-pill переключатель дизайн-системы.
/// Используется на экранах «Меню» (Видео/Фото) и «Афиша» (Афиша/Новости).
class PiligrimSegmentedControl extends StatelessWidget {
  const PiligrimSegmentedControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(tabs.length == 2);

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const double height = 36;
  static const double radius = 18;
  static const double trackWidth = 184;
  static const double _pillInset = 3;

  @override
  Widget build(BuildContext context) {
    final isFirst = selectedIndex == 0;
    const innerWidth = trackWidth - _pillInset * 2;
    const pillWidth = innerWidth / 2;
    const pillRadius = radius - _pillInset;

    return SizedBox(
      width: trackWidth,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PiligrimColors.earthDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: PiligrimColors.divider),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_pillInset),
              child: AnimatedAlign(
                duration: 280.ms,
                curve: Curves.easeOutCubic,
                alignment:
                    isFirst ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: PiligrimColors.water.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(pillRadius),
                    border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PiligrimColors.water.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _SegmentTab(
                    label: tabs[i],
                    active: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  static const _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? PiligrimColors.water
        : PiligrimColors.sky.withValues(alpha: 0.45);

    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PiligrimSegmentedControl.radius),
      child: SizedBox(
        height: PiligrimSegmentedControl.height,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -0.5),
            child: AnimatedDefaultTextStyle(
              duration: 220.ms,
              curve: Curves.easeOut,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w300,
                letterSpacing: active ? 0.6 : 0.4,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                textHeightBehavior: _textHeightBehavior,
                strutStyle: const StrutStyle(
                  fontSize: 11.5,
                  height: 1.0,
                  leading: 0,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
