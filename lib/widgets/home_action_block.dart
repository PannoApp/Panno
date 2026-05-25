// Блок действий главного экрана — CTA «Забронировать стол»
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/auth_guard.dart';
import '../screens/booking_screen.dart';
import 'ember_cta.dart';

class HomeActionBlock extends StatelessWidget {
  const HomeActionBlock({super.key, this.bottomPadding = 0});

  /// Доп. нижний отступ — обычно `MediaQuery.padding.bottom` от Scaffold с
  /// `extendBody: true`. Без него EmberCta «уплывает» под прозрачный navbar.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 8),
      child: EmberCta(
        label: 'Забронировать стол',
        showTrailingArrow: false,
        labelFontSize: 15.5,
        labelOffset: const Offset(-14, 0),
        onTap: () async {
          if (!await guardAuth(context)) return;
          if (!context.mounted) return;
          await Navigator.of(context).push(
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
    );
  }
}
