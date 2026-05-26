import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Показывает диалог подтверждения. `true` — удалить, `false`/`null` — отмена.
Future<bool?> showPiligrimDeleteAccountDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Удалить аккаунт',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const Center(child: _DeleteDialog());
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog();

  static const _surface = Color(0xFF1C1916);
  static const _divider = Color(0x14F2ECE1);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width - 72).clamp(268.0, 300.0);

    return Material(
      color: PiligrimColors.clear,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: SizedBox(
          width: dialogWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PiligrimColors.sky.withValues(alpha: 0.06),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: PiligrimColors.shadow.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Удалить аккаунт',
                          textAlign: TextAlign.center,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            height: 1.25,
                            letterSpacing: 0.15,
                            color: PiligrimColors.sky.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Профиль, бронирования и уведомления будут '
                          'удалены без возможности восстановления.',
                          textAlign: TextAlign.center,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w300,
                            height: 1.35,
                            letterSpacing: 0.05,
                            color: PiligrimColors.sky.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 0.5, thickness: 0.5, color: _divider),
                  _KeepAccountButton(
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const Divider(height: 0.5, thickness: 0.5, color: _divider),
                  _DeleteAccountButton(
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAccountButton extends StatelessWidget {
  const _KeepAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Center(
          child: Text(
            'Оставить аккаунт',
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.1,
              color: PiligrimColors.sky.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  static const _emberMuted = Color(0xFF9A6B4A);

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Center(
          child: Text(
            'Удалить аккаунт',
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.05,
              color: _emberMuted,
            ),
          ),
        ),
      ),
    );
  }
}
