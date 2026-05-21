import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';
import 'booking_history_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.date,
    required this.time,
    required this.heroesCount,
    this.zone,
    required this.depositRequired,
  });

  final String date;
  final String time;
  final int heroesCount;
  final String? zone;
  final bool depositRequired;

  // Склонение по русским правилам: герой / героя / героев
  String _formatHeroesCount(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return '$count герой';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$count героя';
    } else {
      return '$count героев';
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final pushes = <String>[
      'Заявка принята, мы свяжемся с вами в течение 15 минут.',
      'После подтверждения менеджером: бронь подтверждена на $date, $time.',
      'Напоминание за 1-2 часа до визита.',
    ];
    if (depositRequired) {
      pushes.add('Для выбранного стола нужен депозит — менеджер направит вас на звонок.');
    }

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        children: [
          const Positioned.fill(
            child: PiligrimBackground(
              textureOpacity: 0.45,
              vignetteIntensity: 0.25,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: top + 20),
                  // Анимированный тотем успеха
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PiligrimColors.water.withValues(alpha: 0.1),
                        border: Border.all(
                          color: PiligrimColors.water.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.water.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: SvgPicture.asset(
                        'assets/images/bird_totem (1).svg',
                        colorFilter: const ColorFilter.mode(
                          PiligrimColors.water,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut)
                        .rotate(duration: 600.ms, curve: Curves.easeOut),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ПУТЬ ЗАБРОНИРОВАН',
                    textAlign: TextAlign.center,
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 20,
                      color: PiligrimColors.sky,
                      letterSpacing: 2.5,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Ваша заявка успешно отправлена проводникам',
                    textAlign: TextAlign.center,
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 32),
                  // Карточка деталей
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: PiligrimColors.earthDeep,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PiligrimColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: PiligrimColors.shadow.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: 'assets/images/sun.svg',
                          label: 'Дата и время',
                          value: '$date, $time',
                        ),
                        const Divider(height: 24, color: PiligrimColors.divider),
                        _DetailRow(
                          icon: 'assets/images/shaman.svg',
                          label: 'Количество героев',
                          value: _formatHeroesCount(heroesCount),
                        ),
                        if (zone != null && zone!.isNotEmpty) ...[
                          const Divider(height: 24, color: PiligrimColors.divider),
                          _DetailRow(
                            icon: 'assets/images/star_totem (1).svg',
                            label: 'Зона / Зал',
                            value: zone!,
                          ),
                        ],
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 450.ms, duration: 500.ms)
                      .scale(begin: const Offset(0.95, 0.95), duration: 500.ms),
                  const SizedBox(height: 28),
                  // Инструкции / Что дальше
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сценарий после отправки',
                          style: PiligrimTextStyles.heading.copyWith(
                            color: PiligrimColors.steppe,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...pushes.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: PiligrimColors.water,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: PiligrimTextStyles.body.copyWith(
                                      color: PiligrimColors.sky.withValues(alpha: 0.8),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 500.ms),
                  ),
                  // Кнопки управления
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // pushReplacement — экран формы убирается из стека, история встаёт на его место
                      PiligrimTap(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const BookingHistoryScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PiligrimColors.water,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'МОИ БРОНИРОВАНИЯ',
                            style: PiligrimTextStyles.button.copyWith(
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // popUntil — возврат к корневому маршруту (RootShell / IndexedStack)
                      PiligrimTap(
                        onTap: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: PiligrimColors.sky.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            'НА ГЛАВНУЮ',
                            style: PiligrimTextStyles.button.copyWith(
                              fontSize: 13,
                              color: PiligrimColors.sky.withValues(alpha: 0.9),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: bottom + 16),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Строка детали с иконкой-тотемом, подписью и значением (дата, кол-во героев, зал)
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          icon,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            PiligrimColors.water.withValues(alpha: 0.6),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                color: PiligrimColors.sky.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 14,
                color: PiligrimColors.sky,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
