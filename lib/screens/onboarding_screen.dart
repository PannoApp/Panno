// Онбординг — «Начало пути / Обряд инициации»
// Брендбук §7: «Вертикальный скролл, звезда ведёт вниз по линии пути»
// ТЗ §9: Онбординг = «Начало пути (обряд инициации)»
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../widgets/ember_cta.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _loading = false;

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStart() async {
    setState(() => _loading = true);
    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        await context.read<AuthProvider>().updateDisplayProfile(
              firstName: firstName.isNotEmpty ? firstName : null,
              lastName: lastName.isNotEmpty ? lastName : null,
            );
      }
    } catch (_) {
      // поля необязательны — не блокируем продолжение
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RootShell(),
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PiligrimColors.earthSurface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Атмосферный фон ──────────────────────────────────────────────
          const PiligrimBackground(
            cinematic: true,
            textureOpacity: 0.40,
            vignetteIntensity: 0.35,
          ),

          // ── Тёплое свечение снизу (огненный мотив, ТЗ §7) ───────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.12),
                    PiligrimColors.steppe.withValues(alpha: 0.04),
                    PiligrimColors.clear,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Контент ──────────────────────────────────────────────────────
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              32,
              top + 56,
              32,
              bottom + 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Звезда-тотем + вертикальная линия пути ─────────────────
                _PathTotem(shimmerCtrl: _shimmerCtrl),
                const SizedBox(height: 36),

                // ── Приветствие ─────────────────────────────────────────────
                Text(
                  'Добро пожаловать,\nГерой',
                  style: PiligrimTextStyles.display.copyWith(
                    fontSize: 34,
                    height: 1.18,
                    letterSpacing: 0.4,
                    color: PiligrimColors.sky,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 600.ms)
                    .slideY(begin: 0.05, end: 0, duration: 600.ms,
                        curve: Curves.easeOutCubic),
                const SizedBox(height: 10),

                Text(
                  'Начало пути — расскажите о себе.\nПоля необязательны.',
                  style: PiligrimTextStyles.body.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.48),
                    fontSize: 14,
                    height: 1.55,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 36),

                // ── Поля ────────────────────────────────────────────────────
                _BrandField(
                  controller: _firstNameCtrl,
                  hint: 'Имя',
                  delay: 380.ms,
                ),
                const SizedBox(height: 14),
                _BrandField(
                  controller: _lastNameCtrl,
                  hint: 'Фамилия',
                  delay: 460.ms,
                ),
                const SizedBox(height: 48),

                // ── CTA — «Начать путь» ──────────────────────────────────────
                _loading
                    ? const _TotemPulseLoader()
                    : EmberCta(
                        label: 'НАЧАТЬ ПУТЬ',
                        iconAsset: 'assets/images/star_totem (1).svg',
                        onTap: _onStart,
                      )
                        .animate()
                        .fadeIn(delay: 540.ms, duration: 600.ms)
                        .slideY(begin: 0.06, end: 0, duration: 600.ms,
                            curve: Curves.easeOutCubic),
                const SizedBox(height: 20),

                // ── Подсказка «пропустить» ───────────────────────────────────
                Center(
                  child: PiligrimTap(
                    onTap: _loading ? null : _onStart,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        'Пропустить',
                        style: PiligrimTextStyles.caption.copyWith(
                          color: PiligrimColors.sky.withValues(alpha: 0.28),
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Звезда-тотем + вертикальная линия пути
// ─────────────────────────────────────────────────────────────────────────────
class _PathTotem extends StatelessWidget {
  const _PathTotem({required this.shimmerCtrl});

  final AnimationController shimmerCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Звезда с пульсирующим свечением
        AnimatedBuilder(
          animation: shimmerCtrl,
          builder: (_, child) {
            final t = shimmerCtrl.value;
            final pulse = 0.78 +
                0.15 * math.sin(t * math.pi * 2.1) +
                0.07 * math.sin(t * math.pi * 5.3);
            return Opacity(
              opacity: (pulse).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PiligrimColors.water
                          .withValues(alpha: (0.15 + pulse * 0.08).clamp(0, 0.30)),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/images/star_totem (1).svg',
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(
              PiligrimColors.water,
              BlendMode.srcIn,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 700.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.65, 0.65),
              end: const Offset(1.0, 1.0),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),

        // Вертикальная линия пути
        Container(
          width: 1,
          height: 36,
          margin: const EdgeInsets.only(left: 15.5),
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
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

        // Точка
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PiligrimColors.steppe.withValues(alpha: 0.55),
          ),
        ).animate().fadeIn(delay: 380.ms, duration: 400.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Брендованное поле ввода
// ─────────────────────────────────────────────────────────────────────────────
class _BrandField extends StatelessWidget {
  const _BrandField({
    required this.controller,
    required this.hint,
    required this.delay,
  });

  final TextEditingController controller;
  final String hint;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: PiligrimTextStyles.body.copyWith(
        color: PiligrimColors.sky,
        fontSize: 16,
        height: 1.4,
      ),
      cursorColor: PiligrimColors.water,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: PiligrimTextStyles.body.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.22),
          fontSize: 15,
        ),
        filled: true,
        fillColor: PiligrimColors.earthDeep.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: PiligrimColors.sky.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: PiligrimColors.water,
            width: 1,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 500.ms)
        .slideY(
          begin: 0.04,
          end: 0,
          delay: delay,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Тотем-лоадер — пульсирующая звезда вместо CircularProgressIndicator
// ─────────────────────────────────────────────────────────────────────────────
class _TotemPulseLoader extends StatefulWidget {
  const _TotemPulseLoader();

  @override
  State<_TotemPulseLoader> createState() => _TotemPulseLoaderState();
}

class _TotemPulseLoaderState extends State<_TotemPulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final t = _ctrl.value;
            final pulse = 0.5 + 0.5 * math.sin(t * math.pi);
            return Opacity(
              opacity: (0.40 + pulse * 0.55).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.80 + pulse * 0.20,
                child: child,
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/images/star_totem (1).svg',
            width: 28,
            height: 28,
            colorFilter: const ColorFilter.mode(
              PiligrimColors.steppe,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
