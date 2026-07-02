import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'piligrim_loader.dart';
import 'piligrim_tap.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PILIGRIM CTA SYSTEM
// Единая система кнопок — три уровня иерархии.
//
// Hero CTA  →  PathCta (path_cta.dart) — только главный экран и hero-секции.
// Primary   →  PrimaryCtaButton — главные действия в формах.
// Secondary →  SecondaryCtaButton — вспомогательные действия.
// Text      →  TextCtaButton — мягкие навигационные действия.
// ─────────────────────────────────────────────────────────────────────────────

/// Primary CTA — кремовая кнопка с тёмным текстом.
///
/// «Дорогой физический материал» — без gradient, без glow, без оранжевых оттенков.
/// Ощущение матовой керамики или тёплой слоновой кости.
///
/// Применяется: ОТПРАВИТЬ ЗАЯВКУ, ПОЛУЧИТЬ КОД, ПОДТВЕРДИТЬ, ЗАПИСАТЬСЯ,
/// НАЧАТЬ ПУТЬ, СОХРАНИТЬ ИЗМЕНЕНИЯ и все главные финальные действия форм.
class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.height = 52.0,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !isLoading;

    return PiligrimTap(
      onTap: isLoading ? null : onTap,
      borderRadius: PiligrimRadius.buttonAll,
      scaleDown: 0.97,
      pressedOpacity: 0.88,
      releaseDuration: const Duration(milliseconds: 300),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: PiligrimRadius.buttonAll,
          color: disabled ? PiligrimColors.earthDeep : PiligrimColors.nomadCream,
          border: disabled
              ? Border.all(
                  color: PiligrimColors.steppe.withValues(alpha: 0.20),
                )
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const PiligrimLoader(
                size: 20,
                color: PiligrimColors.steppe,
              )
            : Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: PiligrimFonts.museoSans,
                  fontWeight: FontWeight.w300,
                  fontSize: 12.5,
                  height: 1.0,
                  letterSpacing: 3.2,
                  color: disabled
                      ? PiligrimColors.sky.withValues(alpha: 0.28)
                      : PiligrimColors.textDark,
                ),
              ),
      ),
    );
  }
}

/// Secondary CTA — контурная кнопка без заливки.
///
/// Прозрачный фон с тонким контуром steppe. Для вспомогательных действий
/// рядом с основным CTA или вместо него, когда действие не финальное.
///
/// Применяется: ПОЗВОНИТЬ МЕНЕДЖЕРУ, вторичные альтернативы внутри форм.
class SecondaryCtaButton extends StatelessWidget {
  const SecondaryCtaButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 48.0,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: PiligrimRadius.buttonAll,
      scaleDown: 0.97,
      releaseDuration: const Duration(milliseconds: 300),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: PiligrimRadius.buttonAll,
          border: Border.all(
            color: PiligrimColors.steppe.withValues(alpha: 0.38),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: PiligrimFonts.museoSans,
            fontWeight: FontWeight.w300,
            fontSize: 12.0,
            height: 1.0,
            letterSpacing: 2.4,
            color: PiligrimColors.steppe.withValues(alpha: 0.80),
          ),
        ),
      ),
    );
  }
}

/// Text CTA — текстовая ссылка-действие без контейнера.
///
/// Минимальное визуальное присутствие. Для мягких навигационных действий
/// где контейнер создавал бы лишний визуальный вес.
///
/// Применяется: «Изменить номер», «Пропустить», ссылки на политики.
class TextCtaButton extends StatelessWidget {
  const TextCtaButton({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.fontSize = 12.5,
    this.letterSpacing = 0.4,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: PiligrimFonts.museoSans,
            fontWeight: FontWeight.w300,
            fontSize: fontSize,
            height: 1.0,
            letterSpacing: letterSpacing,
            color: color ?? PiligrimColors.sky.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }
}
