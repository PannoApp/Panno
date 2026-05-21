// Горизонтальный фильтр галереи интерьера по зонам (Главный зал, Терраса, …)
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        // +1 для чипа «Все»
        itemCount: zones.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          // Первый элемент — «Все зоны»
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? PiligrimColors.steppe.withValues(alpha: 0.20)
              : PiligrimColors.earthDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? PiligrimColors.steppe.withValues(alpha: 0.50)
                : PiligrimColors.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 12,
            color: isActive
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: 0.65),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
