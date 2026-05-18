// Блок действий главного экрана — CTA «Забронировать» + текстовые ссылки
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../screens/booking_screen.dart';
import 'piligrim_tap.dart';
import 'ember_cta.dart';

class HomeActionBlock extends StatelessWidget {
  const HomeActionBlock({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmberCta(
            label: 'Забронировать стол',
            iconAsset: 'assets/images/moon_totem (1).svg',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookingScreen(),
                ),
              );
            },
          )
              .animate(delay: 60.ms)
              .fadeIn(duration: 520.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.96, 0.96),
                end: const Offset(1, 1),
                duration: 540.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 24),
          HomeTextLink(
            label: 'Меню ресторана',
            delay: 160.ms,
            onTap: () => onNavigate?.call(1),
          ),
          const SizedBox(height: 14),
          HomeTextLink(
            label: 'Как добраться',
            delay: 240.ms,
            onTap: () => onNavigate?.call(4),
          ),
        ],
      ),
    );
  }
}

// Текстовая ссылка со стрелкой → (навигация внутри приложения)
class HomeTextLink extends StatelessWidget {
  const HomeTextLink({
    super.key,
    required this.label,
    this.onTap,
    this.delay = Duration.zero,
  });

  final String label;
  final VoidCallback? onTap;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: PiligrimColors.water.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '→',
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 12,
                color: PiligrimColors.water.withValues(alpha: 0.4),
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
