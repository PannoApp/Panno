// Вход по телефону — SMS OTP (Auth Guard pattern).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/ember_cta.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
    final ok = await context.read<AuthProvider>().confirmOtp(
          _phoneCtrl.text.trim(),
          code,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = context.read<AuthProvider>().error ?? 'Неверный код';
    });
  }

  void _backToPhone() {
    setState(() {
      _awaitingCode = false;
      _codeCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PiligrimTap(
          onTap: () {
            if (_awaitingCode) {
              _backToPhone();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Text(
          'Начать путь',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 17,
            color: PiligrimColors.sky,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: PiligrimBackground(cinematic: true)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _awaitingCode ? 'Код из SMS' : 'Войдите как герой',
                      style: PiligrimTextStyles.display.copyWith(
                        fontSize: 26,
                        height: 1.2,
                        color: PiligrimColors.sky,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _awaitingCode
                          ? 'Мы отправили код на ${_phoneCtrl.text.trim()}'
                          : 'Телефон нужен для брони стола и записи на события. '
                              'Мы не списываем оплату в приложении.',
                      style: PiligrimTextStyles.body.copyWith(
                        fontSize: 13,
                        height: 1.55,
                        color: PiligrimColors.sky.withValues(alpha: 0.72),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: PiligrimTextStyles.body.copyWith(
                          fontSize: 13,
                          color: PiligrimColors.ember,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (!_awaitingCode) ...[
                      Text(
                        'Телефон',
                        style: PiligrimTextStyles.caption.copyWith(
                          color: PiligrimColors.water.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d+\s\-()]'),
                          ),
                        ],
                        style: PiligrimTextStyles.body.copyWith(
                          color: PiligrimColors.sky,
                          fontSize: 16,
                        ),
                        decoration: _fieldDecoration('+7 7XX XXX XX XX'),
                        validator: (v) {
                          final digits =
                              (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 11) {
                            return 'Укажите номер телефона';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      Text(
                        'Код',
                        style: PiligrimTextStyles.caption.copyWith(
                          color: PiligrimColors.water.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: PiligrimTextStyles.body.copyWith(
                          color: PiligrimColors.sky,
                          fontSize: 16,
                          letterSpacing: 4,
                        ),
                        decoration: _fieldDecoration('0000'),
                      ),
                    ],
                    const Spacer(),
                    EmberCta(
                      label: _submitting
                          ? 'Подождите…'
                          : (_awaitingCode ? 'Подтвердить' : 'Получить код'),
                      iconAsset: 'assets/images/moon_totem (1).svg',
                      onTap: _submitting
                          ? null
                          : (_awaitingCode ? _confirmCode : _requestCode),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: PiligrimTextStyles.body.copyWith(
        color: PiligrimColors.sky.withValues(alpha: 0.35),
        fontSize: 15,
      ),
      filled: true,
      fillColor: PiligrimColors.earthDeep.withValues(alpha: 0.65),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: PiligrimColors.sky.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: PiligrimColors.sky.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: PiligrimColors.water.withValues(alpha: 0.45),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: PiligrimColors.ember.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
