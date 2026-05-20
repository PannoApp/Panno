// Splash Screen — «Начало пути» (согласно piligrim_design_spec.md, раздел 9)
// Анимации на встроенном AnimationController (без flutter_animate — стабильнее на iOS).
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/home_data.dart';
import '../core/theme.dart';
import '../data/repositories/core_repository.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.coreRepository,
    this.onNavigateToHome,
  });

  final CoreRepository? coreRepository;

  /// Переопределяет переход на главный экран — используется в тестах.
  final VoidCallback? onNavigateToHome;

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

  // Баннер «рекомендуем обновить» — показывается при min ≤ current < latest
  bool _showUpdateBanner = false;
  String _bannerStoreUrl = '';

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

    Future<void>.delayed(_navigateAfter, _checkVersionThenNavigate);
  }

  Future<void> _checkVersionThenNavigate() async {
    if (!mounted) return;

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final info = await (widget.coreRepository ?? CoreRepository())
          .fetchAppVersion(platform);

      final current = _parseVersion(kAppVersion);
      final min = _parseVersion(info.minVersion);
      final latest = _parseVersion(info.latestVersion);

      if (_versionLessThan(current, min)) {
        // Версия ниже минимальной — неотклоняемый диалог с переходом в магазин
        if (!mounted) return;
        await _showForceUpdateDialog(info.storeUrl);
        return; // не переходим на главную — пользователь заблокирован
      }

      if (_versionLessThan(current, latest)) {
        // Версия между min и latest — показываем отклоняемый баннер после навигации
        if (mounted) {
          setState(() {
            _showUpdateBanner = true;
            _bannerStoreUrl = info.storeUrl;
          });
        }
      }
    } catch (_) {
      // Ошибка сети — молча продолжаем, не блокируем запуск
    }

    _goToHome();
  }

  // Разбирает строку "major.minor.patch" в список из трёх int
  List<int> _parseVersion(String v) {
    final parts = v.split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }

  // Возвращает true если a строго меньше b (сравнение major → minor → patch)
  bool _versionLessThan(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] < b[i]) return true;
      if (a[i] > b[i]) return false;
    }
    return false; // равны
  }

  Future<void> _showForceUpdateDialog(String storeUrl) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // неотклоняемый
      builder: (ctx) => PopScope(
        canPop: false, // запрещаем закрытие кнопкой «назад»
        child: AlertDialog(
          backgroundColor: PiligrimColors.earthDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Необходимо обновление',
            style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
          ),
          content: Text(
            'Ваша версия приложения устарела. Пожалуйста, обновите приложение, чтобы продолжить.',
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.75),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(storeUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                'Обновить',
                style: PiligrimTextStyles.button.copyWith(color: PiligrimColors.water),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToHome() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isNewUser) {
      auth.isNewUser = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
      return;
    }
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
            child: Transform.translate(
              offset: const Offset(0, -6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStarTotem(),
                  const SizedBox(height: 8),
                  _buildPathLine(),
                  const SizedBox(height: 20),
                  _buildLogo(),
                  const SizedBox(height: 20),
                  _buildTagline(),
                  const SizedBox(height: 20),
                  _buildConcept(),
                ],
              ),
            ),
          ),
          _buildBottomLabel(),
          if (_showUpdateBanner) _buildUpdateBanner(),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PiligrimColors.earthDeep,
                PiligrimColors.earth,
                PiligrimColors.earthWarm,
                PiligrimColors.earthDeep,
              ],
              stops: [0.0, 0.36, 0.72, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                PiligrimColors.ember.withValues(alpha: 0.15),
                PiligrimColors.steppe.withValues(alpha: 0.05),
                PiligrimColors.clear,
              ],
              stops: [0.0, 0.40, 0.80],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PiligrimColors.earthDeep.withValues(alpha: 0.34),
                PiligrimColors.clear,
                PiligrimColors.clear,
                PiligrimColors.earthDeep.withValues(alpha: 0.52),
              ],
              stops: [0.0, 0.30, 0.60, 1.0],
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 52),
        child: Text(
          kModernNomadConcept,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 11.5,
            height: 1.5,
            fontWeight: FontWeight.w300,
            color: PiligrimColors.sky.withValues(alpha: 0.52),
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
            color: PiligrimColors.sky.withValues(alpha: 0.24),
            letterSpacing: 7.5,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Отклоняемый баннер — показывается когда min ≤ current < latest
  Widget _buildUpdateBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PiligrimColors.earthDeep,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PiligrimColors.steppe.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Доступна новая версия приложения',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 13,
                    color: PiligrimColors.sky,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_bannerStoreUrl),
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Обновить',
                  style: PiligrimTextStyles.button.copyWith(color: PiligrimColors.water),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showUpdateBanner = false),
                child: const Icon(Icons.close, size: 16, color: PiligrimColors.navInactive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
