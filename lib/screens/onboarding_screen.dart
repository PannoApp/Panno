// Онбординг — «Начало пути / Обряд инициации»
// Брендбук §7: «Вертикальный скролл, звезда ведёт вниз по линии пути»
// ТЗ §9: Онбординг = «Начало пути (обряд инициации)»
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/path_cta.dart';
import '../widgets/piligrim_tap.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  UserGender? _gender;
  DateTime? _birthday;
  bool _showGenderError = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text = user.lastName;
      _emailCtrl.text = user.email;
      if (user.gender != UserGender.notSpecified) _gender = user.gender;
      _birthday = user.birthday;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            surface: PiligrimColors.earthDeep,
            primary: PiligrimColors.water,
            onPrimary: PiligrimColors.sky,
            onSurface: PiligrimColors.sky,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _selectGender(UserGender gender) {
    setState(() {
      _gender = gender;
      _showGenderError = false;
    });
  }

  /// Основной путь: требует явно выбранного пола. Сохраняет всю анкету.
  Future<void> _onStart() async {
    final gender = _gender;
    if (gender == null) {
      setState(() => _showGenderError = true);
      return;
    }

    setState(() => _loading = true);
    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      await context.read<AuthProvider>().updateDisplayProfile(
            firstName: firstName.isNotEmpty ? firstName : null,
            lastName: lastName.isNotEmpty ? lastName : null,
            gender: gender,
            email: email.isNotEmpty ? email : null,
            birthday: _birthday,
          );
    } catch (_) {
      // сеть могла подвести — не блокируем выход с экрана
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// «Пропустить» — ничего не сохраняет, пол остаётся `not_specified`.
  void _onSkip() {
    if (_loading) return;
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
                  'Начало пути — расскажите о себе.\nПол обязателен, остальное — по желанию.',
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
                const SizedBox(height: 14),
                _BrandField(
                  controller: _emailCtrl,
                  hint: 'Email (необязательно)',
                  delay: 570.ms,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _DateField(
                  value: _birthday,
                  onTap: _pickBirthday,
                  delay: 600.ms,
                ),
                const SizedBox(height: 24),

                // ── Пол (обязательный выбор) ─────────────────────────────────
                Text(
                  'Пол',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.40),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ).animate().fadeIn(delay: 630.ms, duration: 500.ms),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _GenderOption(
                      label: UserGender.male.label,
                      selected: _gender == UserGender.male,
                      onTap: () => _selectGender(UserGender.male),
                      delay: 660.ms,
                    ),
                    const SizedBox(width: 12),
                    _GenderOption(
                      label: UserGender.female.label,
                      selected: _gender == UserGender.female,
                      onTap: () => _selectGender(UserGender.female),
                      delay: 690.ms,
                    ),
                  ],
                ),
                if (_showGenderError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Выберите пол, чтобы продолжить, либо нажмите «Пропустить»',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.fruit,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 48),

                // ── CTA — «Начать путь» ──────────────────────────────────────
                PathCta(
                  label: _loading ? 'ЗАГРУЖАЕМ...' : 'НАЧАТЬ ПУТЬ',
                  onTap: _loading ? null : _onStart,
                )
                    .animate()
                    .fadeIn(delay: 540.ms, duration: 600.ms)
                    .slideY(begin: 0.06, end: 0, duration: 600.ms,
                        curve: Curves.easeOutCubic),
                const SizedBox(height: 20),

                // ── Подсказка «пропустить» ───────────────────────────────────
                Center(
                  child: PiligrimTap(
                    onTap: _loading ? null : _onSkip,
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
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController controller;
  final String hint;
  final Duration delay;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
// Поле «Дата рождения» — открывает showDatePicker, необязательное
// ─────────────────────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onTap,
    required this.delay,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final Duration delay;

  String get _label {
    final d = value;
    if (d == null) return 'Дата рождения (необязательно)';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: PiligrimColors.sky.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
                style: PiligrimTextStyles.body.copyWith(
                  color: value == null
                      ? PiligrimColors.sky.withValues(alpha: 0.22)
                      : PiligrimColors.sky,
                  fontSize: value == null ? 15 : 16,
                  height: 1.4,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: PiligrimColors.sky.withValues(alpha: 0.30),
            ),
          ],
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
// Чип выбора пола — обязательный выбор для «Начать путь»
// ─────────────────────────────────────────────────────────────────────────────
class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.delay,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PiligrimTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? PiligrimColors.water.withValues(alpha: 0.16)
                : PiligrimColors.earthDeep.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? PiligrimColors.water
                  : PiligrimColors.sky.withValues(alpha: 0.10),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: PiligrimTextStyles.body.copyWith(
              color: selected
                  ? PiligrimColors.sky
                  : PiligrimColors.sky.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay, duration: 500.ms);
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
