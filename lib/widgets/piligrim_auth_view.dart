import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'ember_cta.dart';
import 'piligrim_background.dart';
import 'piligrim_tap.dart';

/// Unified centered authentication view widget used in both booking and profile tabs.
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
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        const PiligrimBackground(
          cinematic: true,
          textureOpacity: 0.38,
          vignetteIntensity: 0.18,
        ),
        const Positioned.fill(child: _AuthAtmosphere()),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  PiligrimColors.ember.withValues(alpha: 0.08),
                  PiligrimColors.steppe.withValues(alpha: 0.03),
                  PiligrimColors.clear,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 48, 28, keyboardHeight + 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Логотип ──────────────────────────────────────────
                    SvgPicture.asset(
                      'assets/images/star_totem (1).svg',
                      width: 28,
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        PiligrimColors.sky,
                        BlendMode.srcIn,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: PiligrimColors.sky.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 10),
                    SvgPicture.asset(
                      'assets/images/piligrim.svg',
                      width: 140,
                      colorFilter: const ColorFilter.mode(
                        PiligrimColors.sky,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Форма авторизации ─────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Подпись
                        Text(
                          _awaitingCode
                              ? 'Код отправлен на ${_phoneCtrl.text.trim()}'
                              : 'Сначала нужно авторизоваться',
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.sky.withValues(alpha: 0.45),
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: PiligrimTextStyles.body.copyWith(
                              fontSize: 13,
                              color: PiligrimColors.ember,
                            ),
                          ),
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
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.sky,
                            fontSize: 16,
                            letterSpacing: _awaitingCode ? 4 : 0,
                          ),
                          cursorColor: PiligrimColors.water,
                          decoration: InputDecoration(
                            hintText: _awaitingCode ? '0000' : '+7 7XX XXX XX XX',
                            hintStyle: PiligrimTextStyles.body.copyWith(
                              color: PiligrimColors.sky.withValues(alpha: 0.30),
                              fontSize: 15,
                              letterSpacing: 0,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: PiligrimColors.earthWarm.withValues(alpha: 0.35),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: PiligrimColors.sky.withValues(alpha: 0.12),
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
                        ),
                        const SizedBox(height: 14),
                        // Кнопка
                        EmberCta(
                          label: _submitting
                              ? 'Подождите…'
                              : (_awaitingCode ? 'ПОДТВЕРДИТЬ' : 'ПОЛУЧИТЬ КОД'),
                          showTrailingArrow: false,
                          onTap: _submitting
                              ? null
                              : (_awaitingCode ? _confirmCode : _requestCode),
                        ),
                        // Изменить номер
                        if (_awaitingCode) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: PiligrimTap(
                              onTap: () => setState(() {
                                _awaitingCode = false;
                                _codeCtrl.clear();
                                _error = null;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Text(
                                  'Изменить номер',
                                  style: PiligrimTextStyles.caption.copyWith(
                                    color: PiligrimColors.sky.withValues(alpha: 0.30),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
                stops: const [0.0, 0.35, 0.72, 1.0],
                colors: [
                  PiligrimColors.ember.withValues(alpha: 0.06),
                  PiligrimColors.clear,
                  PiligrimColors.earthWarm.withValues(alpha: 0.12),
                  PiligrimColors.earthSurface.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: MediaQuery.sizeOf(context).height * 0.12,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.10),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            bottom: MediaQuery.sizeOf(context).height * 0.18,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.07),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.5, -0.2),
                radius: 1.1,
                colors: [
                  PiligrimColors.clear,
                  PiligrimColors.shadow.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
