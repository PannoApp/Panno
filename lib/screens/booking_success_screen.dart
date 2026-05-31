import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_nav_button.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.date,
    required this.time,
    required this.heroesCount,
    this.zone,
  });

  final String date;
  final String time;
  final int heroesCount;
  final String? zone;

  String _formatHeroesCount(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count герой';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$count героя';
    }
    return '$count героев';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        children: [
          const Positioned.fill(
            child: PiligrimBackground(
              textureOpacity: 0.5,
              vignetteIntensity: 0.4,
              cinematic: true,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Тотем — малый, вторичный, тёплый
                  SvgPicture.asset(
                    'assets/images/bird_totem (1).svg',
                    width: 28,
                    height: 28,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.steppe.withValues(alpha: 0.55),
                      BlendMode.srcIn,
                    ),
                  ).animate().fadeIn(duration: 700.ms),

                  const SizedBox(height: 22),

                  // Editorial-заголовок — двухстрочный, широкий трекинг
                  Text(
                    'ПУТЬ\nЗАБРОНИРОВАН',
                    textAlign: TextAlign.center,
                    style: PiligrimTextStyles.title.copyWith(
                      fontSize: 26,
                      color: PiligrimColors.sky,
                      letterSpacing: 4.5,
                      height: 1.3,
                    ),
                  ).animate().fadeIn(delay: 180.ms, duration: 700.ms),

                  const SizedBox(height: 14),

                  Text(
                    'Ваша заявка передана проводникам',
                    textAlign: TextAlign.center,
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                      fontSize: 13,
                      letterSpacing: 0.5,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 700.ms),

                  const SizedBox(height: 44),

                  // Детали без карточки — интегрированы в пространство
                  const Divider(height: 1, color: Color(0x14F2ECE1))
                      .animate()
                      .fadeIn(delay: 420.ms, duration: 500.ms),

                  _DetailLine(
                    label: 'ДАТА И ВРЕМЯ',
                    value: '$date, $time',
                    animDelay: 480.ms,
                  ),

                  const Divider(height: 1, color: Color(0x14F2ECE1))
                      .animate()
                      .fadeIn(delay: 540.ms, duration: 500.ms),

                  _DetailLine(
                    label: 'КОЛИЧЕСТВО ГЕРОЕВ',
                    value: _formatHeroesCount(heroesCount),
                    animDelay: 580.ms,
                  ),

                  if (zone != null && zone!.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0x14F2ECE1))
                        .animate()
                        .fadeIn(delay: 640.ms, duration: 500.ms),
                    _DetailLine(
                      label: 'ЗОНА / ЗАЛ',
                      value: zone!,
                      animDelay: 680.ms,
                    ),
                  ],

                  const Divider(height: 1, color: Color(0x14F2ECE1))
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 500.ms),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),

          // Кнопка закрытия
          Positioned(
            top: top + 8,
            right: 8,
            child: PiligrimNavButton(
              icon: Icons.close,
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.animDelay = Duration.zero,
  });

  final String label;
  final String value;
  final Duration animDelay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: PiligrimTextStyles.caption.copyWith(
              fontSize: 10,
              color: PiligrimColors.sky.withValues(alpha: 0.38),
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 15,
                color: PiligrimColors.sky.withValues(alpha: 0.92),
                fontWeight: FontWeight.w300,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: animDelay, duration: 600.ms);
  }
}
