import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/profile_data.dart';
import '../core/theme.dart';
import '../data/models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/core_info_provider.dart';
import 'piligrim_background.dart';
import 'piligrim_member_number_dialog.dart';
import 'path_cta.dart';
import 'piligrim_cta.dart';

/// Маска ввода номера для казахстанского рынка: префикс `+7 ` подставляется
/// автоматически, пользователь набирает только оставшиеся 10 цифр.
///
/// Цифры считаются от текста без статического префикса — иначе цифра '7'
/// из самого префикса каждый раз попадала бы в счёт вместе с набранными.
class KzPhoneInputFormatter extends TextInputFormatter {
  static const _prefix = '+7 ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text;
    if (raw.startsWith(_prefix)) {
      raw = raw.substring(_prefix.length);
    } else if (raw.startsWith('+7')) {
      raw = raw.substring(2);
    } else if (raw.startsWith('+')) {
      raw = raw.substring(1);
    }

    var digits = raw.replaceAll(RegExp(r'\D'), '');

    // Вставили номер целиком (напр. из буфера обмена) вместе с кодом страны
    // или домашней восьмёркой — убираем этот ведущий символ.
    if (oldValue.text.isEmpty &&
        digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final buffer = StringBuffer(_prefix);
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Шаг экрана входа/регистрации PILIGRIM (см. docs/piligrim_improvements_plan.md,
/// Фаза D). SMS-код полностью убран из UI — основной путь теперь «телефон +
/// номер участника лояльности», для новых гостей — короткая регистрация.
enum _AuthStep { phone, login, register }

/// Экран авторизации PILIGRIM.
/// Бренд-блок и форма — единая вертикальная композиция, центрированная на экране.
class PiligrimAuthView extends StatefulWidget {
  const PiligrimAuthView({
    super.key,
    required this.onSuccess,
  });

  final void Function(bool isNewUser) onSuccess;

  @override
  State<PiligrimAuthView> createState() => _PiligrimAuthViewState();
}

class _PiligrimAuthViewState extends State<PiligrimAuthView> {
  final _phoneCtrl = TextEditingController();
  final _memberNumberCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  _AuthStep _step = _AuthStep.phone;
  bool _submitting = false;
  String? _error;
  UserGender? _gender;
  DateTime? _birthday;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _memberNumberCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  /// Номер в чистом E.164-формате (+7XXXXXXXXXX) для отправки на бэкенд —
  /// поле хранит его с пробелами для читаемости, серверный regex пробелов не допускает.
  String get _cleanPhone => _phoneCtrl.text.replaceAll(RegExp(r'[^\d+]'), '');

  void _continueFromPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) {
      setState(() => _error = 'Укажите номер телефона');
      return;
    }
    // По умолчанию предполагаем, что у гостя уже есть карта лояльности
    // (программа существовала до приложения) — регистрация доступна
    // отдельной ссылкой на этом шаге.
    setState(() {
      _error = null;
      _step = _AuthStep.login;
    });
  }

  void _switchToRegister() {
    setState(() {
      _error = null;
      _step = _AuthStep.register;
    });
  }

  void _switchToLogin() {
    setState(() {
      _error = null;
      _step = _AuthStep.login;
    });
  }

  void _changePhone() {
    setState(() {
      _error = null;
      _memberNumberCtrl.clear();
      _step = _AuthStep.phone;
    });
  }

  Future<void> _login() async {
    final memberNumber = _memberNumberCtrl.text.trim();
    if (memberNumber.isEmpty) {
      setState(() => _error = 'Введите номер участника');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithMemberNumber(_cleanPhone, memberNumber);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      widget.onSuccess(false);
    } else {
      setState(() => _error = auth.error ?? 'Не удалось войти');
    }
  }

  Future<void> _register() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) {
      setState(() => _error = 'Укажите имя');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      phone: _cleanPhone,
      firstName: firstName,
      lastName: _lastNameCtrl.text.trim(),
      birthday: _birthday,
      gender: _gender,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      setState(() => _error = auth.error ?? 'Не удалось зарегистрироваться');
      return;
    }

    // Remarked присвоил номер участника синхронно — показываем его один раз,
    // прежде чем уйти с экрана (см. lastRegisteredMemberNumber). Поля анкеты
    // уже собраны при регистрации — OnboardingScreen после этого не нужен,
    // поэтому очищаем isNewUser здесь, а не полагаемся на onSuccess/вызывающий
    // код (он всё ещё проверяет флаг для старого SMS-флоу).
    final memberNumber = auth.lastRegisteredMemberNumber;
    auth.clearNewUserFlag();
    if (memberNumber != null && memberNumber.isNotEmpty && mounted) {
      await showPiligrimMemberNumberDialog(context, memberNumber);
    }
    if (!mounted) return;
    widget.onSuccess(false);
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

  /// Открывает WhatsApp-чат администратора с заготовленным текстом обращения
  /// (ТЗ по входу, п.4 «Восстановление номера лояльности»). Номер/текст
  /// берутся из RestaurantInfo (админка), с фолбэком на константы в
  /// lib/core/profile_data.dart, пока контент не заполнен.
  Future<void> _openLoyaltyRecoveryChat() async {
    final coreInfo = context.read<CoreInfoProvider>().coreInfo;
    final phone = coreInfo?.loyaltyRecoveryWhatsapp?.isNotEmpty == true
        ? coreInfo!.loyaltyRecoveryWhatsapp!
        : kLoyaltyRecoveryWhatsapp;
    final message = coreInfo?.loyaltyRecoveryMessage?.isNotEmpty == true
        ? coreInfo!.loyaltyRecoveryMessage!
        : kLoyaltyRecoveryMessage;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => _error = 'Не удалось открыть WhatsApp');
      }
    }
  }

  String get _headline => switch (_step) {
        _AuthStep.phone => 'НАЧАТЬ ПУТЬ',
        _AuthStep.login => 'ВХОД ПО НОМЕРУ УЧАСТНИКА',
        _AuthStep.register => 'РЕГИСТРАЦИЯ',
      };

  Widget _buildStepFields() {
    switch (_step) {
      case _AuthStep.phone:
        return _PhoneField(controller: _phoneCtrl);
      case _AuthStep.login:
        return _MemberNumberField(controller: _memberNumberCtrl);
      case _AuthStep.register:
        return _RegisterFields(
          firstNameCtrl: _firstNameCtrl,
          lastNameCtrl: _lastNameCtrl,
          birthday: _birthday,
          gender: _gender,
          onPickBirthday: _pickBirthday,
          onSelectGender: (g) => setState(() => _gender = g),
        );
    }
  }

  String get _ctaLabel => switch (_step) {
        _AuthStep.phone => _submitting ? 'ЗАГРУЖАЕМ...' : 'ПРОДОЛЖИТЬ',
        _AuthStep.login => _submitting ? 'ВХОДИМ...' : 'ВОЙТИ',
        _AuthStep.register =>
          _submitting ? 'РЕГИСТРИРУЕМ...' : 'ЗАРЕГИСТРИРОВАТЬСЯ',
      };

  VoidCallback? get _ctaAction {
    if (_submitting) return null;
    return switch (_step) {
      _AuthStep.phone => _continueFromPhone,
      _AuthStep.login => _login,
      _AuthStep.register => _register,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    // Высота экрана без safe area — для ConstrainedBox чтобы Column.center работал
    final availableHeight =
        screenHeight - mediaPadding.top - mediaPadding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Фон ────────────────────────────────────────────────────────────
        const PiligrimBackground(cinematic: true),
        const Positioned.fill(child: _AuthAtmosphere()),
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
                  PiligrimColors.ember.withValues(alpha: 0.07),
                  PiligrimColors.clear,
                ],
              ),
            ),
          ),
        ),

        // ── Единая центрированная композиция ─────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            // Когда клавиатура поднимается — добавляем отступ, чтобы
            // поле и кнопка не скрывались за ней.
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              keyboardHeight > 0 ? keyboardHeight + 16 : 0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Column(
                // center распределяет свободное пространство поровну сверху
                // и снизу. SizedBox(80) в конце смещает всю группу на 40px
                // выше геометрического центра — без Spacer (он ломает ScrollView).
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Бренд-блок ─────────────────────────────────────────
                  const Center(child: _BrandPillar()),

                  const SizedBox(height: 20),

                  // Короткий типографский орнамент — соединяет бренд с формой,
                  // не делит экран на зоны
                  Center(
                    child: Container(
                      width: 48,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PiligrimColors.clear,
                            PiligrimColors.sky.withValues(alpha: 0.14),
                            PiligrimColors.clear,
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Форма ──────────────────────────────────────────────

                  // Мини-заголовок
                  AnimatedSwitcher(
                    duration: 280.ms,
                    child: Text(
                      _headline,
                      key: ValueKey('headline_$_step'),
                      textAlign: TextAlign.center,
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.35),
                        fontSize: 9,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                  if (_step != _AuthStep.phone) ...[
                    const SizedBox(height: 6),
                    Text(
                      _phoneCtrl.text.trim(),
                      textAlign: TextAlign.center,
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.28),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 280.ms),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: PiligrimTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: PiligrimColors.ember,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ).animate().fadeIn(duration: 250.ms),
                  ],

                  const SizedBox(height: 14),

                  // Поля шага — телефон / номер участника / форма регистрации
                  AnimatedSwitcher(
                    duration: 280.ms,
                    child: KeyedSubtree(
                      key: ValueKey('fields_$_step'),
                      child: _buildStepFields(),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 10),

                  // Кнопка — та же ширина, что и поле
                  PathCta(
                    label: _ctaLabel,
                    onTap: _ctaAction,
                  ).animate().fadeIn(duration: 400.ms, delay: 360.ms),

                  if (_step == _AuthStep.phone) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Номер используется только\nдля бронирований и участия в событиях',
                      textAlign: TextAlign.center,
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.20),
                        fontSize: 11,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 420.ms),
                  ],

                  if (_step == _AuthStep.login) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextCtaButton(
                        label: 'Изменить номер телефона',
                        onTap: _changePhone,
                      ).animate().fadeIn(duration: 300.ms),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextCtaButton(
                        label: 'Забыл свой номер лояльности',
                        onTap: _openLoyaltyRecoveryChat,
                      ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextCtaButton(
                        label: 'У меня нет карты — регистрация',
                        onTap: _switchToRegister,
                      ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
                    ),
                  ],

                  if (_step == _AuthStep.register) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextCtaButton(
                        label: 'Изменить номер телефона',
                        onTap: _changePhone,
                      ).animate().fadeIn(duration: 300.ms),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextCtaButton(
                        label: 'У меня уже есть номер лояльности',
                        onTap: _switchToLogin,
                      ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
                    ),
                  ],

                  // Смещение вверх: group center = screen center − 40px
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Общий стиль текстового поля формы входа ─────────────────────────────────
InputDecoration _authFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: PiligrimTextStyles.body.copyWith(
      color: PiligrimColors.sky.withValues(alpha: 0.25),
      fontSize: 15,
      letterSpacing: 0,
    ),
    counterText: '',
    filled: true,
    fillColor: PiligrimColors.earthWarm.withValues(alpha: 0.32),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: PiligrimColors.sky.withValues(alpha: 0.10),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: PiligrimColors.water,
        width: 1,
      ),
    ),
  );
}

// ── Шаг 1: телефон ───────────────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [KzPhoneInputFormatter()],
      style: PiligrimTextStyles.body.copyWith(
        color: PiligrimColors.sky,
        fontSize: 16,
      ),
      cursorColor: PiligrimColors.water,
      decoration: _authFieldDecoration('+7 7XX XXX XX XX'),
    );
  }
}

// ── Шаг 2: номер участника лояльности ───────────────────────────────────────
class _MemberNumberField extends StatelessWidget {
  const _MemberNumberField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: PiligrimTextStyles.body.copyWith(
        color: PiligrimColors.sky,
        fontSize: 16,
        letterSpacing: 3,
      ),
      cursorColor: PiligrimColors.water,
      decoration: _authFieldDecoration('Номер участника (см. карту в Apple Wallet)'),
    );
  }
}

// ── Шаг 3: форма регистрации ────────────────────────────────────────────────
class _RegisterFields extends StatelessWidget {
  const _RegisterFields({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.birthday,
    required this.gender,
    required this.onPickBirthday,
    required this.onSelectGender,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final DateTime? birthday;
  final UserGender? gender;
  final VoidCallback onPickBirthday;
  final ValueChanged<UserGender> onSelectGender;

  String get _birthdayLabel {
    final d = birthday;
    if (d == null) return 'Дата рождения (необязательно)';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: firstNameCtrl,
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky,
            fontSize: 16,
          ),
          cursorColor: PiligrimColors.water,
          decoration: _authFieldDecoration('Имя'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: lastNameCtrl,
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky,
            fontSize: 16,
          ),
          cursorColor: PiligrimColors.water,
          decoration: _authFieldDecoration('Фамилия (необязательно)'),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onPickBirthday,
          child: InputDecorator(
            decoration: _authFieldDecoration(''),
            child: Text(
              _birthdayLabel,
              style: PiligrimTextStyles.body.copyWith(
                color: birthday == null
                    ? PiligrimColors.sky.withValues(alpha: 0.25)
                    : PiligrimColors.sky,
                fontSize: birthday == null ? 15 : 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GenderChip(
                label: UserGender.male.label,
                selected: gender == UserGender.male,
                onTap: () => onSelectGender(UserGender.male),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GenderChip(
                label: UserGender.female.label,
                selected: gender == UserGender.female,
                onTap: () => onSelectGender(UserGender.female),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? PiligrimColors.water.withValues(alpha: 0.16)
              : PiligrimColors.earthWarm.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
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
    );
  }
}

// ── Бренд-блок: ✦ → ось → PILIGRIM → MODERN NOMAD ──────────────────────────
// Размеры откалиброваны под единую композицию с формой:
// звезда 40px, ось 72px, лого 190px.
class _BrandPillar extends StatelessWidget {
  const _BrandPillar();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Звезда: 40px — держит верх, не доминирует
        SvgPicture.asset(
          'assets/images/star_totem (1).svg',
          width: 40,
          height: 40,
          colorFilter: ColorFilter.mode(
            PiligrimColors.sky.withValues(alpha: 0.85),
            BlendMode.srcIn,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 80.ms),

        // Ось: 72px — пропорциональна новым размерам
        Container(
          width: 1,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PiligrimColors.sky.withValues(alpha: 0.22),
                PiligrimColors.sky.withValues(alpha: 0.05),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 700.ms, delay: 160.ms),

        // Логотип: 190px — главный элемент, не перевешивает композицию
        SvgPicture.asset(
          'assets/images/piligrim.svg',
          width: 190,
          colorFilter: ColorFilter.mode(
            PiligrimColors.sky.withValues(alpha: 0.88),
            BlendMode.srcIn,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 280.ms),

        const SizedBox(height: 16),

        // Философия бренда
        Text(
          'MODERN NOMAD',
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.28),
            fontSize: 9,
            letterSpacing: 7,
            fontWeight: FontWeight.w300,
            height: 1.0,
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
      ],
    );
  }
}

// ── Атмосферные слои фона ────────────────────────────────────────────────────
class _AuthAtmosphere extends StatelessWidget {
  const _AuthAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.40, 0.75, 1.0],
                colors: [
                  PiligrimColors.ember.withValues(alpha: 0.05),
                  PiligrimColors.clear,
                  PiligrimColors.earthWarm.withValues(alpha: 0.10),
                  PiligrimColors.earthSurface.withValues(alpha: 0.50),
                ],
              ),
            ),
          ),
          Positioned(
            left: -80,
            top: MediaQuery.sizeOf(context).height * 0.10,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.08),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -50,
            bottom: MediaQuery.sizeOf(context).height * 0.16,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.06),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
