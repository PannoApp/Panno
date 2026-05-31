// Онбординг — «Начало пути / Обряд инициации»
// Брендбук §7: «Вертикальный скролл, звезда ведёт вниз по линии пути»
// ТЗ §9: Онбординг = «Начало пути (обряд инициации)»
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/ember_cta.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text = user.lastName;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
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
    Navigator.of(context).pop();
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
                // ── Логотип PILIGRIM ──────────────────────────────────────
                SvgPicture.asset(
                  'assets/images/piligrim.svg',
                  height: 26,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.sky,
                    BlendMode.srcIn,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                    .slideX(
                      begin: -0.1,
                      end: 0,
                      duration: 700.ms,
                      curve: Curves.easeOutCubic,
                    ),
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
                const SizedBox(height: 14),
                _PhoneReadOnly(
                  phone: context.read<AuthProvider>().currentUser?.phone ?? '',
                  delay: 530.ms,
                ),
                const SizedBox(height: 48),

                // ── CTA — «Начать путь» ──────────────────────────────────────
                _loading
                    ? const _TotemPulseLoader()
                    : EmberCta(
                        label: 'НАЧАТЬ ПУТЬ',
                        showTrailingArrow: false,
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

          // ── Кнопка «Назад» поверх контента — только при push из профиля ──
          // Расположена последней в Stack, чтобы получать нажатия раньше
          // SingleChildScrollView (RenderViewport всегда захватывает hitTest).
          if (Navigator.of(context).canPop())
            Positioned(
              top: top + 12,
              left: 16,
              child: PiligrimTap(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 12,
                        color: PiligrimColors.sky.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Назад',
                        style: PiligrimTextStyles.caption.copyWith(
                          color: PiligrimColors.sky.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
            ),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Read-only поле телефона
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneReadOnly extends StatelessWidget {
  const _PhoneReadOnly({required this.phone, required this.delay});

  final String phone;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: PiligrimColors.sky.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              phone,
              style: PiligrimTextStyles.body.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.35),
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: PiligrimColors.sky.withValues(alpha: 0.20),
          ),
        ],
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
