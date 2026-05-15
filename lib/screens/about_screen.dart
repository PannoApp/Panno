// О нас — контакты, адрес, история бренда. Будет реализован в следующей итерации.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../widgets/piligrim_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/wheel_totem (1).svg',
                    width: 48,
                    height: 48,
                    colorFilter: const ColorFilter.mode(
                      PiligrimColors.sky,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'О НАС',
                    style: PiligrimTextStyles.title.copyWith(
                      letterSpacing: 4,
                      color: PiligrimColors.sky,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Контакты и информация\nв разработке',
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
