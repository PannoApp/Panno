// Splash Screen — «Начало пути» (согласно piligrim_design_spec.md, раздел 9)
// Фон: Қара жер #3D3A38, логотип — кремовый #F2EDE4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/home_data.dart';
import '../core/theme.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RootShell(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: anim,
              child: child,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundLayer(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/star_totem (1).svg',
                  width: 48,
                  height: 48,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.water,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 1,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        PiligrimColors.water,
                        PiligrimColors.divider,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SvgPicture.asset(
                  'assets/images/piligrim.svg',
                  height: 72,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.sky,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'дәстүрдің дәмі',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.water,
                    letterSpacing: 2.5,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'еркіндік лебі',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.steppe.withValues(alpha: 0.7),
                    letterSpacing: 2.5,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    kModernNomadConcept,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w300,
                      color: PiligrimColors.sky.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'PILIGRIM',
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.35),
                letterSpacing: 8,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.2,
          colors: [
            Color(0xFF4A4744),
            PiligrimColors.earth,
            PiligrimColors.earthDeep,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
