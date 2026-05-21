// Типографика под hero — на textured background, не на фотографии.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../core/home_data.dart';

class HomeHeroIntroBlock extends StatefulWidget {
  const HomeHeroIntroBlock({super.key});

  @override
  State<HomeHeroIntroBlock> createState() => _HomeHeroIntroBlockState();
}

class _HomeHeroIntroBlockState extends State<HomeHeroIntroBlock> {
  int _phraseIndex = 0;
  late Timer _phraseTimer;

  static const _titleSwitchDuration = Duration(milliseconds: 1600);
  static const _titleCurve = Cubic(0.33, 0.0, 0.18, 1.0);

  @override
  void initState() {
    super.initState();
    _phraseTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        setState(() => _phraseIndex = (_phraseIndex + 1) % kHeroPhrases.length);
      }
    });
  }

  @override
  void dispose() {
    _phraseTimer.cancel();
    super.dispose();
  }

  Widget _titleTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: _titleCurve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.028),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Разделитель между hero-фото и текстовым блоком
          Container(
            margin: const EdgeInsets.only(bottom: 28),
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PiligrimColors.sky.withValues(alpha: 0.0),
                  PiligrimColors.sky.withValues(alpha: 0.10),
                  PiligrimColors.sky.withValues(alpha: 0.10),
                  PiligrimColors.sky.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 900.ms, curve: Curves.easeOut),
          SvgPicture.asset(
            'assets/images/piligrim.svg',
            height: 28,
            colorFilter: const ColorFilter.mode(
              PiligrimColors.sky,
              BlendMode.srcIn,
            ),
          )
              .animate()
              .fadeIn(duration: 1100.ms, curve: Curves.easeOut),

          const SizedBox(height: 28),

          SizedBox(
            height: 76,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: _titleSwitchDuration,
                switchInCurve: _titleCurve,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, _) =>
                    currentChild ?? const SizedBox.shrink(),
                transitionBuilder: _titleTransition,
                child: Text(
                  kHeroPhrases[_phraseIndex],
                  key: ValueKey<int>(_phraseIndex),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PiligrimTextStyles.display.copyWith(
                    fontSize: 28,
                    height: 1.18,
                    color: PiligrimColors.sky,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 1200.ms, curve: Curves.easeOut),

          const SizedBox(height: 12),

          Text(
            kModernNomadConcept,
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.35,
              color: PiligrimColors.sky.withValues(alpha: 0.72),
            ),
          )
              .animate()
              .fadeIn(delay: 420.ms, duration: 1000.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
