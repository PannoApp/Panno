// Splash Screen — «Начало пути» (согласно piligrim_design_spec.md, раздел 9)
// Анимации на встроенном AnimationController (без flutter_animate — стабильнее на iOS).
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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _shimmer;
  late final Animation<double> _starOpacity;
  late final Animation<double> _starScale;
  late final Animation<double> _pathReveal;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _conceptOpacity;
  late final Animation<double> _bottomOpacity;

  static const _navigateAfter = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _starOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.33, curve: Curves.easeOut),
    );
    _starScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutBack),
    );
    _pathReveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.25, 0.50, curve: Curves.easeOut),
    );
    _logoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.33, 0.71, curve: Curves.easeOut),
    );
    _logoSlide = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.33, 0.71, curve: Curves.easeOutCubic),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.58, 0.88, curve: Curves.easeOut),
    );
    _conceptOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.67, 0.96, curve: Curves.easeOut),
    );
    _bottomOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _intro.forward();
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _shimmer.repeat(reverse: true);
    });

    Future<void>.delayed(_navigateAfter, _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
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

  @override
  void dispose() {
    _intro.dispose();
    _shimmer.dispose();
    super.dispose();
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
                _buildStarTotem(),
                const SizedBox(height: 8),
                _buildPathLine(),
                const SizedBox(height: 16),
                _buildLogo(),
                const SizedBox(height: 20),
                _buildTagline(),
                const SizedBox(height: 18),
                _buildConcept(),
              ],
            ),
          ),
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
            Color(0xFF4A4744),
            PiligrimColors.earth,
            PiligrimColors.earthDeep,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildStarTotem() {
    return AnimatedBuilder(
      animation: Listenable.merge([_starOpacity, _starScale, _shimmer]),
      builder: (context, child) {
        final scale = 0.6 + 0.4 * _starScale.value;
        final shimmer = 0.85 + 0.15 * _shimmer.value;
        return Opacity(
          opacity: (_starOpacity.value * shimmer).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SvgPicture.asset(
        'assets/images/star_totem (1).svg',
        width: 48,
        height: 48,
        colorFilter: const ColorFilter.mode(
          PiligrimColors.water,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildPathLine() {
    return AnimatedBuilder(
      animation: _pathReveal,
      builder: (context, child) {
        return Opacity(
          opacity: _pathReveal.value.clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _pathReveal.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
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
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoOpacity, _logoSlide]),
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - _logoSlide.value)),
            child: child,
          ),
        );
      },
      child: SvgPicture.asset(
        'assets/images/piligrim.svg',
        height: 72,
        colorFilter: const ColorFilter.mode(
          PiligrimColors.sky,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineOpacity,
      child: Column(
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
      ),
    );
  }

  Widget _buildConcept() {
    return FadeTransition(
      opacity: _conceptOpacity,
      child: Padding(
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
    );
  }

  Widget _buildBottomLabel() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _bottomOpacity,
        child: Text(
          'PILIGRIM',
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.2),
            letterSpacing: 8,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
