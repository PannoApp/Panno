import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'piligrim_background.dart';
import 'path_cta.dart';
import 'piligrim_cta.dart';

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
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  bool _awaitingCode = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) {
      setState(() => _error = 'Укажите номер телефона');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _awaitingCode = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.read<AuthProvider>().error ?? 'Не удалось отправить код';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Введите код из SMS');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmOtp(_phoneCtrl.text.trim(), code);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      widget.onSuccess(auth.isNewUser);
    } else {
      setState(() => _error = auth.error ?? 'Неверный код');
    }
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
                      _awaitingCode ? 'ВВЕДИТЕ КОД' : 'НАЧАТЬ ПУТЬ',
                      key: ValueKey('headline_$_awaitingCode'),
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

                  if (_awaitingCode) ...[
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

                  // Поле ввода
                  TextField(
                    controller: _awaitingCode ? _codeCtrl : _phoneCtrl,
                    keyboardType: _awaitingCode
                        ? TextInputType.number
                        : TextInputType.phone,
                    maxLength: _awaitingCode ? 4 : null,
                    inputFormatters: _awaitingCode
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d+\s\-()]')),
                          ],
                    textAlign:
                        _awaitingCode ? TextAlign.center : TextAlign.start,
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky,
                      fontSize: 16,
                      letterSpacing: _awaitingCode ? 6 : 0,
                    ),
                    cursorColor: PiligrimColors.water,
                    decoration: InputDecoration(
                      hintText:
                          _awaitingCode ? '0  0  0  0' : '+7 7XX XXX XX XX',
                      hintStyle: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.25),
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor:
                          PiligrimColors.earthWarm.withValues(alpha: 0.32),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 15),
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
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 10),

                  // Кнопка — та же ширина, что и поле
                  PathCta(
                    label: _submitting
                        ? (_awaitingCode ? 'ПОДТВЕРЖДАЕМ...' : 'ОТПРАВЛЯЕМ...')
                        : (_awaitingCode ? 'ПОДТВЕРДИТЬ' : 'ПОЛУЧИТЬ КОД'),
                    onTap: _submitting
                        ? null
                        : (_awaitingCode ? _confirmCode : _requestCode),
                  ).animate().fadeIn(duration: 400.ms, delay: 360.ms),

                  if (!_awaitingCode) ...[
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

                  if (_awaitingCode) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextCtaButton(
                        label: 'Изменить номер',
                        onTap: () => setState(() {
                          _awaitingCode = false;
                          _codeCtrl.clear();
                          _error = null;
                        }),
                      ).animate().fadeIn(duration: 300.ms),
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
