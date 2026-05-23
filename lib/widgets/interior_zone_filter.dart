import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Горизонтальный скролл фильтров по зонам.
///
/// [zones] — уникальные зоны из API (zone-код и отображаемое название).
/// [selectedZone] == null означает «Все зоны».
class InteriorZoneFilter extends StatelessWidget {
  const InteriorZoneFilter({
    super.key,
    required this.zones,
    required this.selectedZone,
    required this.onSelect,
  });

  final List<({String zone, String label})> zones;
  final String? selectedZone;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: zones.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _ZoneChip(
              label: 'Все',
              isActive: selectedZone == null,
              onTap: () => onSelect(null),
            );
          }
          final zone = zones[i - 1];
          return _ZoneChip(
            label: zone.label,
            isActive: selectedZone == zone.zone,
            onTap: () => onSelect(zone.zone),
          );
        },
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? PiligrimColors.water.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? PiligrimColors.water.withValues(alpha: 0.55)
                : PiligrimColors.sky.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 12,
            letterSpacing: 0.3,
            color: isActive
                ? PiligrimColors.water
                : PiligrimColors.sky.withValues(alpha: 0.55),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w300,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
