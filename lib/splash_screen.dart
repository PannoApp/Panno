import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_page.dart';

// Палитра из cursorrules (строго)
const _kBg    = Color(0xFF3D3A38); // Қара жер
const _kWhite = Color(0xFFF2EDE4); // Ақ аспан — текст на тёмном
const _kSub   = Color(0xFF7BA5B8); // Мөлдір су — вторичный текст

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // 1. Линия рисуется сверху вниз
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineProgress; // 0→1 (длина линии)

  // 2. Звезда появляется в начале
  late final AnimationController _starCtrl;
  late final Animation<double> _starFade;
  late final Animation<double> _starScale;

  // 3. Точка и текст появляются в конце линии
  late final AnimationController _textCtrl;
  late final Animation<double> _dotFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _sloganFade;

  // 4. Плавный выход
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _lineProgress = CurvedAnimation(
      parent: _lineCtrl,
      curve: Curves.easeInOutCubic,
    );

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _starFade  = CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOutCubic);
    _starScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOutCubic),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dotFade    = CurvedAnimation(parent: _textCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOutCubic));
    _textFade   = CurvedAnimation(parent: _textCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOutCubic));
    _textSlide  = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl,
            curve: const Interval(0.2, 0.9, curve: Curves.easeInOutCubic)));
    _sloganFade = CurvedAnimation(parent: _textCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOutCubic));

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOutCubic),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Сначала появляется звезда
    await _starCtrl.forward();
    // Потом рисуется линия
    await _lineCtrl.forward();
    // Потом появляется текст
    await _textCtrl.forward();
    // Пауза (не анимация — пользователь воспринимает логотип)
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    // Выход
    await _exitCtrl.forward();
    if (!mounted || _navigated) return;
    _navigated = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        pageBuilder: (_, _, _) => const HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _starCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Звезда стартует на 15% высоты, линия идёт до 72%
    final starY     = size.height * 0.15;
    final lineTop   = starY + 20;
    final lineBottom = size.height * 0.72;
    final lineLength = lineBottom - lineTop;

    return Scaffold(
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_lineCtrl, _starCtrl, _textCtrl, _exitCtrl]),
        builder: (_, _) {
          return Opacity(
            opacity: _exitFade.value,
            child: Stack(
              children: [

                // ── Звезда (4-лучевая) ────────────────────────────────────
                Positioned(
                  top: starY - 16,
                  left: 0, right: 0,
                  child: FadeTransition(
                    opacity: _starFade,
                    child: ScaleTransition(
                      scale: _starScale,
                      child: Center(
                        child: CustomPaint(
                          size: const Size(32, 32),
                          painter: _StarPainter(),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Вертикальная линия ────────────────────────────────────
                Positioned(
                  top: lineTop,
                  left: size.width / 2 - 0.7,
                  child: Container(
                    width: 1.4,
                    height: lineLength * _lineProgress.value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _kWhite.withValues(alpha: 0.9),
                          _kWhite.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Точка в конце линии ───────────────────────────────────
                Positioned(
                  top: lineBottom + 6,
                  left: 0, right: 0,
                  child: FadeTransition(
                    opacity: _dotFade,
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kWhite.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Текст "piligrim" ──────────────────────────────────────
                Positioned(
                  top: lineBottom + 20,
                  left: 0, right: 0,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            'piligrim',
                            style: GoogleFonts.outfit(
                              fontSize: 38,
                              fontWeight: FontWeight.w300,
                              color: _kWhite,
                              height: 1.0,
                              letterSpacing: 6.0,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Слоган на казахском
                          FadeTransition(
                            opacity: _sloganFade,
                            child: Column(
                              children: [
                                Text(
                                  'дәстүрдің дәмі мен',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 1.5,
                                    color: _kSub.withValues(alpha: 0.7),
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'еркіндік лебі',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 1.5,
                                    color: _kSub.withValues(alpha: 0.7),
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final double outerV = size.height * 0.50;
    final double outerH = size.width  * 0.30;
    final double ctrl   = size.width  * 0.06;

    final points = [
      Offset(cx,          cy - outerV),
      Offset(cx + ctrl,   cy - ctrl),
      Offset(cx + outerH, cy),
      Offset(cx + ctrl,   cy + ctrl),
      Offset(cx,          cy + outerV),
      Offset(cx - ctrl,   cy + ctrl),
      Offset(cx - outerH, cy),
      Offset(cx - ctrl,   cy - ctrl),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length; i++) {
      final cp  = points[i];
      final end = points[(i + 1) % points.length];
      path.quadraticBezierTo(cp.dx, cp.dy, end.dx, end.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = _kWhite..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
