// Splash Screen — «Начало пути» (согласно piligrim_design_spec.md, раздел 9)
// Фон: Қара жер #3D3A38, логотип — кремовый #F2EDE4, анимация звезды-тотема
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/home_data.dart';
import '../core/theme.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Переход на главный экран через 3.2 секунды (после завершения анимации)
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
          // Фоновая текстура — тонкий градиент для глубины
          _buildBackgroundLayer(),

          // Центральный блок: логотип + слоган
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Звезда-тотем — «обряд инициации»
                _buildStarTotem(),

                const SizedBox(height: 8),

                // Вертикальная линия — «путь»
                _buildPathLine(),

                const SizedBox(height: 16),

                // Логотип PILIGRIM (SVG)
                _buildLogo(),

                const SizedBox(height: 20),

                // Слоган на казахском — главная версия
                _buildTagline(),

                const SizedBox(height: 18),

                // ТЗ: краткое представление концепции Modern Nomad
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
                )
                    .animate(delay: 1600.ms)
                    .fadeIn(duration: 700.ms, curve: Curves.easeOut),
              ],
            ),
          ),

          // Нижняя надпись — тонкая, почти невидимая
          _buildBottomLabel(),
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
            Color(0xFF4A4744), // чуть светлее к центру
            PiligrimColors.earth,
            PiligrimColors.earthDeep, // темнее по краям
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildStarTotem() {
    return SvgPicture.asset(
      'assets/images/star_totem (1).svg',
      width: 48,
      height: 48,
      colorFilter: const ColorFilter.mode(
        PiligrimColors.water,
        BlendMode.srcIn,
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.0, 1.0),
          duration: 1000.ms,
          curve: Curves.easeOutBack,
        )
        .then(delay: 200.ms)
        .shimmer(
          duration: 1200.ms,
          color: PiligrimColors.sky.withValues(alpha: 0.3),
        );
  }

  Widget _buildPathLine() {
    return Container(
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
    )
        .animate(delay: 600.ms)
        .fadeIn(duration: 600.ms)
        .scaleY(begin: 0.0, end: 1.0, duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/images/piligrim.svg',
      height: 72,
      colorFilter: const ColorFilter.mode(
        PiligrimColors.sky,
        BlendMode.srcIn,
      ),
    )
        .animate(delay: 800.ms)
        .fadeIn(duration: 900.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.15,
          end: 0.0,
          duration: 900.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTagline() {
    return Column(
      children: [
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
      ],
    )
        .animate(delay: 1400.ms)
        .fadeIn(duration: 700.ms, curve: Curves.easeOut);
  }

  Widget _buildBottomLabel() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Text(
        'PILIGRIM',
        style: PiligrimTextStyles.caption.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.2),
          letterSpacing: 8,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      )
          .animate(delay: 1800.ms)
          .fadeIn(duration: 600.ms),
    );
  }
}
