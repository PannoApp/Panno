// Онбординг нового пользователя — приветствие и необязательные поля имени/фамилии
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
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
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RootShell(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Добро пожаловать,\nГерой',
                style: PiligrimTextStyles.heading.copyWith(
                  fontSize: 30,
                  color: PiligrimColors.sky,
                  height: 1.2,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.06, end: 0, duration: 600.ms),
              const SizedBox(height: 12),
              Text(
                'Расскажите немного о себе (необязательно)',
                style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
              const SizedBox(height: 28),
              TextField(
                controller: _firstNameCtrl,
                style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky,
                  fontSize: 16,
                ),
                decoration: _fieldDecoration('Имя'),
              ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameCtrl,
                style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky,
                  fontSize: 16,
                ),
                decoration: _fieldDecoration('Фамилия'),
              ).animate().fadeIn(delay: 320.ms, duration: 500.ms),
              const SizedBox(height: 48),
              PiligrimTap(
                borderRadius: BorderRadius.circular(10),
                onTap: _loading ? null : _onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: PiligrimColors.water.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PiligrimColors.water,
                            ),
                          )
                        : Text(
                            'НАЧАТЬ ПУТЬ',
                            style: PiligrimTextStyles.button.copyWith(
                              color: PiligrimColors.water,
                              letterSpacing: 2.5,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: PiligrimTextStyles.caption.copyWith(
        color: PiligrimColors.sky.withValues(alpha: 0.25),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: PiligrimColors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: PiligrimColors.water),
      ),
    );
  }
}
