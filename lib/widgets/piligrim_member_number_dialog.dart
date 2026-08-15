import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Показывает гостю его новый номер участника лояльности сразу после
/// регистрации (Remarked присваивает его синхронно — см.
/// docs/piligrim_improvements_plan.md, Фаза B вопрос 1b). Гость должен
/// запомнить/записать номер — это единственный момент, когда он его видит
/// напрямую, дальше он используется только при входе.
Future<void> showPiligrimMemberNumberDialog(
  BuildContext context,
  String memberNumber,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Номер участника',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(child: _MemberNumberDialog(memberNumber: memberNumber));
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

class _MemberNumberDialog extends StatelessWidget {
  const _MemberNumberDialog({required this.memberNumber});

  final String memberNumber;

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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ваш номер участника',
                          textAlign: TextAlign.center,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            height: 1.25,
                            letterSpacing: 0.15,
                            color: PiligrimColors.sky.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          memberNumber,
                          textAlign: TextAlign.center,
                          style: PiligrimTextStyles.display.copyWith(
                            fontSize: 32,
                            letterSpacing: 1.5,
                            color: PiligrimColors.sky,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Запомните или запишите его — он понадобится '
                          'для следующего входа в приложение.',
                          textAlign: TextAlign.center,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w300,
                            height: 1.4,
                            letterSpacing: 0.05,
                            color: PiligrimColors.sky.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 0.5, thickness: 0.5, color: _divider),
                  PiligrimTap(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.zero,
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: Center(
                        child: Text(
                          'Понятно',
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                            color: PiligrimColors.water,
                          ),
                        ),
                      ),
                    ),
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
