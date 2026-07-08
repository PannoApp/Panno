import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Кнопка «Назад» для `AppBar.leading` — общий вид для всех экранов с пушем
/// (иконка + подпись). Используй вместе с `AppBar.leadingWidth: kWidth`,
/// иначе контент переполняет узкую leading-область AppBar.
class PiligrimBackButton extends StatelessWidget {
  const PiligrimBackButton({super.key, this.onTap});

  /// Кастомный обработчик — по умолчанию `Navigator.pop()`.
  final VoidCallback? onTap;

  /// Ширина, которую нужно передать в `AppBar.leadingWidth`.
  static const double kWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: PiligrimTap(
        onTap: onTap ?? () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 12,
                color: PiligrimColors.sky.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 5),
              Text(
                'Назад',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
