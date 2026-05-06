import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu_data.dart';
import 'tiktok_menu.dart';

// ── Цветовая система Piligrim — официальный брендбук ──────────────────────────
// Названия по-казахски согласно брендбуку
const _copper  = Color(0xFF7BA5B8);   // Мөлдір су — главный акцент (стальной синий)
const _copperD = Color(0x8C7BA5B8);   // Мөлдір су 55%
const _ember   = Color(0xFFC4956A);   // Сары дала — тёплый второй акцент
const _fruit   = Color(0xFF8B1A1A);   // Піскен жеміс — CTA / тёмно-красный
const _bg1     = Color(0xFF2A2826);   // Қара жер — поверхности карточек
const _bg2     = Color(0xFF3D3A38);   // Қара жер — основной фон
const _bg3     = Color(0xFF333030);   // Қара жер — приподнятые поверхности
const _bg4     = Color(0xFF1E1C1A);   // Қара жер — глубокий (таббар)
const _txt     = Color(0xFFF2EDE4);   // Ақ аспан — основной текст (кремовый)
const _txtDim  = Color(0x73F2EDE4);   // Ақ аспан 45%
const _txtMid  = Color(0xB8F2EDE4);   // Ақ аспан 72%
const _glassB  = Color(0x1AF2EDE4);   // разделители

// ── Корень ─────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;

  void _goToMenu() => setState(() => _tabIndex = 1);

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeTab(onGoToMenu: _goToMenu),
      const _MenuTab(),
      const _InteriorTab(),
      const _EventsTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: _bg2,
      extendBodyBehindAppBar: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey(_tabIndex), child: tabs[_tabIndex]),
      ),
      bottomNavigationBar: _TabBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

// ── Нижняя навигация ──────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TabBar({required this.currentIndex, required this.onTap});

  static const _labels = ['ГЛАВНАЯ', 'МЕНЮ', 'ИНТЕРЬЕР', 'АФИША', 'ПРОФИЛЬ'];
  // Тотемные символы — официальный брендбук Piligrim
  static const _totems = ['✦', '◈', '⊕', '☽', '◇'];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF0E0C0A),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(
        children: List.generate(5, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: active ? 20 : 16,
                        color: active ? _copper : _txtDim,
                      ),
                      child: Text(_totems[i]),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: GoogleFonts.outfit(
                        fontSize: 7,
                        letterSpacing: 0.5,
                        color: active ? _copper : _txtDim,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w300,
                      ),
                      child: Text(_labels[i]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ГЛАВНАЯ
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final VoidCallback onGoToMenu;
  const _HomeTab({required this.onGoToMenu});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool get _isOpen {
    final h = DateTime.now().hour;
    return h >= 12 && h < 23;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picks = seasonalPicksFromMock();

    return Container(
      color: _bg4,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // ── Hero — полный экран ───────────────────────────────────────────
          _Hero(isOpen: _isOpen, hoursLabel: '12:00 — 23:00', onGoToMenu: widget.onGoToMenu),

          // ── Инфополоса (адрес, часы, телефон) ────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: const _InfoStrip(),
          ),

          const SizedBox(height: 32),

          // ── Формат ресторана — 3 плитки ───────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(text: 'Наш формат'),
                ),
                const SizedBox(height: 14),
                const _HighlightTiles(),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Ближайшее мероприятие ─────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(text: 'Ближайшее событие'),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FeaturedEventCard(event: _kEvents[0]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── О ресторане ───────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(text: 'О ресторане'),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _AboutCard(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Шеф рекомендует ───────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(text: 'Шеф рекомендует'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 248,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: picks.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(right: i < picks.length - 1 ? 14 : 0),
                      child: _SeasonalCard(dish: picks[i], index: i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero section — полный экран, Modern Nomad ─────────────────────────────────
class _Hero extends StatefulWidget {
  final bool isOpen;
  final String hoursLabel;
  final VoidCallback onGoToMenu;

  const _Hero({
    required this.isOpen,
    required this.hoursLabel,
    required this.onGoToMenu,
  });

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: size.height * 0.78,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Многослойный фон ──────────────────────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0907),
                  Color(0xFF141210),
                  Color(0xFF1E1C18),
                  Color(0xFF1B1916),
                ],
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),

          // Синее свечение (Мөлдір су) — верхний левый угол
          Positioned(
            top: -size.width * 0.1,
            left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _copper.withValues(alpha: 0.18),
                    _copper.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Янтарное свечение (Сары дала) — правый нижний угол (огонь)
          Positioned(
            bottom: size.height * 0.08,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _ember.withValues(alpha: 0.15),
                    _ember.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Тёмно-красный отблеск снизу (костёр у горизонта)
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, 1.4),
                  radius: 1.0,
                  colors: [
                    _fruit.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Декоративная сетка — петроглифы (очень тонкая)
          Positioned.fill(
            child: CustomPaint(painter: _PetroGridPainter()),
          ),

          // Нижний переход в контент
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 180,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF1E1C18)],
                ),
              ),
            ),
          ),

          // ── Верхняя строка: логотип + статус ─────────────────────────────
          Positioned(
            top: topPad + 16,
            left: 22,
            right: 22,
            child: FadeTransition(
              opacity: _fade,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Логотип-пиктограмма
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _copper.withValues(alpha: 0.35), width: 1),
                      color: _copper.withValues(alpha: 0.08),
                    ),
                    child: Center(
                      child: Text(
                        '✦',
                        style: TextStyle(
                          color: _copper,
                          fontSize: 13,
                          shadows: [
                            Shadow(color: _copper.withValues(alpha: 0.7), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PILIGRIM',
                    style: GoogleFonts.outfit(
                      color: _txt.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 5,
                    ),
                  ),
                  const Spacer(),
                  // Статус работы
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isOpen
                          ? const Color(0xFF1A2E1C)
                          : const Color(0xFF2A1010),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isOpen
                            ? const Color(0xFF3A7A4A).withValues(alpha: 0.7)
                            : const Color(0xFF7A3A3A).withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isOpen
                                ? const Color(0xFF5AAA6A)
                                : const Color(0xFFAA5A5A),
                            boxShadow: [
                              BoxShadow(
                                color: widget.isOpen
                                    ? const Color(0xFF5AAA6A).withValues(alpha: 0.8)
                                    : const Color(0xFFAA5A5A).withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isOpen ? 'Открыто · ${widget.hoursLabel}' : 'Закрыто',
                          style: GoogleFonts.outfit(
                            color: widget.isOpen
                                ? const Color(0xFF8ADA9A)
                                : const Color(0xFFDA8A8A),
                            fontSize: 10,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Центральный контент — логотипная вертикаль ────────────────────
          // Согласно брендбуку: звезда → вертикальная линия → точка → название
          Positioned(
            left: 0, right: 0,
            top: size.height * 0.17,
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // "Дорогие герои" — приветствие брендбук п.8
                    Text(
                      'Дорогие герои',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: _ember.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Звезда с усиленным свечением
                    Text(
                      '✦',
                      style: TextStyle(
                        color: _copper,
                        fontSize: 22,
                        shadows: [
                          Shadow(color: _copper.withValues(alpha: 0.9), blurRadius: 24),
                          Shadow(color: _copper.withValues(alpha: 0.4), blurRadius: 48),
                        ],
                      ),
                    ),

                    // Вертикальная линия (из структуры логотипа брендбука)
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _copper.withValues(alpha: 0.8),
                            _copper.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),

                    // Точка (из брендбука)
                    Container(
                      width: 4, height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _copper.withValues(alpha: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color: _copper.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Главное название
                    Text(
                      'PILIGRIM',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: _txt,
                        fontSize: 54,
                        fontWeight: FontWeight.w100,
                        letterSpacing: 18,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Горизонтальный разделитель с тотемами
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 0.5,
                          color: _copper.withValues(alpha: 0.35),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '◈  ◇  ⊕',
                            style: TextStyle(
                              color: _copper.withValues(alpha: 0.45),
                              fontSize: 10,
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 0.5,
                          color: _copper.withValues(alpha: 0.35),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Слоган (из брендбука — казахский вариант)
                    Text(
                      'Кухня свободы и традиций',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: _txtMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'дәстүрдің дәмі  ·  еркіндік лебі',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: _ember.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Кнопки действий ───────────────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: _fade,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _HeroBtn(
                      label: 'Забронировать',
                      totem: '☽',
                      primary: true,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const _BookingSheet(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: _HeroBtn(
                      label: 'Меню',
                      totem: '◈',
                      primary: false,
                      onTap: widget.onGoToMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Подсказка прокрутки
          Positioned(
            bottom: 6,
            left: 0, right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: Text(
                  '↓',
                  style: TextStyle(
                    color: _txt.withValues(alpha: 0.2),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Декоративная сетка петроглифов ────────────────────────────────────────────
class _PetroGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Тонкая горизонтальная/вертикальная сетка (как координатная карта путешествия)
    final linePaint = Paint()
      ..color = const Color(0x057BA5B8)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Декоративные точки на пересечениях (тотемные знаки)
    final dotPaint = Paint()
      ..color = const Color(0x0AC4956A)
      ..style = PaintingStyle.fill;

    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }

    // Диагональные акценты (маршрут путешествия)
    final diagPaint = Paint()
      ..color = const Color(0x038B1A1A)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;

    final double diag = math.sqrt(size.width * size.width + size.height * size.height);
    for (double i = -diag; i < diag * 2; i += step * 3) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), diagPaint);
    }
  }

  @override
  bool shouldRepaint(_PetroGridPainter oldDelegate) => false;
}

// ── Кнопка героя (тотем + текст) ─────────────────────────────────────────────
class _HeroBtn extends StatefulWidget {
  final String label;
  final String totem;
  final bool primary;
  final VoidCallback onTap;

  const _HeroBtn({
    required this.label,
    required this.totem,
    required this.primary,
    required this.onTap,
  });

  @override
  State<_HeroBtn> createState() => _HeroBtnState();
}

class _HeroBtnState extends State<_HeroBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.primary
                ? (_pressed ? _copper.withValues(alpha: 0.85) : _copper)
                : _bg1,
            border: widget.primary
                ? null
                : Border.all(color: _copper.withValues(alpha: 0.3)),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: _copper.withValues(alpha: _pressed ? 0.2 : 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.totem,
                style: TextStyle(
                  fontSize: 18,
                  color: widget.primary ? _txt : _copper,
                  shadows: widget.primary
                      ? null
                      : [Shadow(color: _copper.withValues(alpha: 0.5), blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: widget.primary ? _txt : _txtMid,
                  fontSize: 10,
                  fontWeight: widget.primary ? FontWeight.w500 : FontWeight.w300,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Инфополоса: адрес, часы, телефон ─────────────────────────────────────────
class _InfoStrip extends StatelessWidget {
  const _InfoStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _glassB),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _InfoCell(
            totem: '⊕',
            label: 'Астана',
            value: 'пр. Туран 24',
          ),
          _InfoDivider(),
          _InfoCell(
            totem: '☽',
            label: 'Часы работы',
            value: '12:00 — 23:00',
          ),
          _InfoDivider(),
          _InfoCell(
            totem: '◇',
            label: 'Связь',
            value: '+7 700 000 00 00',
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String totem;
  final String label;
  final String value;

  const _InfoCell({
    required this.totem,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              totem,
              style: TextStyle(
                color: _copper.withValues(alpha: 0.8),
                fontSize: 16,
                shadows: [Shadow(color: _copper.withValues(alpha: 0.4), blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: _txtDim,
                fontSize: 7.5,
                letterSpacing: 1,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _txtMid,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 52,
      color: _glassB,
    );
  }
}

// ── 3 плитки «Наш формат» ─────────────────────────────────────────────────────
class _HighlightTiles extends StatelessWidget {
  const _HighlightTiles();

  static const _tiles = [
    (
      totem: '✦',
      title: 'Авторская\nкухня',
      sub: 'Каждое блюдо — гастрономическое приключение',
      grad: [Color(0xFF1A1814), Color(0xFF12100E)],
    ),
    (
      totem: '◈',
      title: 'Огонь\nи саксаул',
      sub: 'Дым, медь и открытый огонь в каждом рецепте',
      grad: [Color(0xFF1C1410), Color(0xFF120E0A)],
    ),
    (
      totem: '☽',
      title: 'Пространство\nАУА',
      sub: 'Живые события, меняющие ваш мир',
      grad: [Color(0xFF101418), Color(0xFF0A0E12)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tiles.length,
        itemBuilder: (_, i) {
          final t = _tiles[i];
          final isLast = i == _tiles.length - 1;
          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: Container(
              width: 152,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.grad,
                ),
                border: Border.all(color: _glassB),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.totem,
                    style: TextStyle(
                      color: _copper,
                      fontSize: 22,
                      shadows: [Shadow(color: _copper.withValues(alpha: 0.6), blurRadius: 12)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    style: GoogleFonts.outfit(
                      color: _txt,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.sub,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: _txtDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Карточка «О ресторане» ────────────────────────────────────────────────────
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF252220), Color(0xFF1A1816)],
        ),
        border: Border.all(color: _glassB),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя полоса акцента
          Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [
                  _copper.withValues(alpha: 0.8),
                  _ember.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок с логотипной структурой
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '✦',
                      style: TextStyle(
                        color: _copper,
                        fontSize: 14,
                        shadows: [Shadow(color: _copper.withValues(alpha: 0.7), blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PILIGRIM',
                      style: GoogleFonts.outfit(
                        color: _copper,
                        fontSize: 17,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Астана · 2024',
                      style: GoogleFonts.outfit(
                        color: _txtDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Основной текст
                Text(
                  'Духовно-гастрономическое путешествие, '
                  'в котором каждый гость — герой. '
                  'Огонь, медь и дерево саксаула — '
                  'образы, формирующие атмосферу.',
                  style: GoogleFonts.outfit(
                    color: _txtMid,
                    fontSize: 13.5,
                    height: 1.65,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 16),

                // Разделитель
                Container(height: 0.5, color: _glassB),

                const SizedBox(height: 14),

                // Цитата-принцип (брендбук: Вкус жизни. Путь героя.)
                Row(
                  children: [
                    Container(
                      width: 2,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: _ember.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Вкус жизни. Путь героя.',
                          style: GoogleFonts.outfit(
                            color: _ember.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Мы ваши проводники. Удачного вам пути.',
                          style: GoogleFonts.outfit(
                            color: _txtDim,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Сезонная карточка ─────────────────────────────────────────────────────────
class _SeasonalCard extends StatelessWidget {
  final MockMenuDish dish;
  final int index;

  const _SeasonalCard({required this.dish, required this.index});

  static const _grads = [
    [Color(0xFF252220), Color(0xFF17150E)],
    [Color(0xFF1E2028), Color(0xFF101218)],
    [Color(0xFF282320), Color(0xFF181412)],
    [Color(0xFF201E18), Color(0xFF121008)],
  ];

  static const _catSymbols = {
    'Супы': '◈', 'Холодное': '◇', 'Горячее': '✦',
    'Десерты': '✧', 'Напитки': '◆', 'Вино': '❖',
  };

  static const _catAccents = {
    'Супы':     Color(0xFFC4956A),   // Сары дала — тёплый
    'Холодное': Color(0xFF7BA5B8),   // Мөлдір су — синий
    'Горячее':  Color(0xFFC4956A),   // тёплый
    'Десерты':  Color(0xFFD4B080),   // светло-степ
    'Напитки':  Color(0xFF7BA5B8),   // синий
    'Вино':     Color(0xFF8B3A3A),   // Піскен жеміс derived
  };

  @override
  Widget build(BuildContext context) {
    final g      = _grads[index % _grads.length];
    final sym    = _catSymbols[dish.category] ?? '✦';
    final accent = _catAccents[dish.category] ?? _copper;
    final num    = '0${index + 1}';

    return Container(
      width: 172,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: _ember.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Text(
                      sym,
                      style: TextStyle(
                        fontSize: 70,
                        color: accent.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 10,
                  child: Text(
                    num,
                    style: GoogleFonts.outfit(
                      color: _copper.withValues(alpha: 0.15),
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      dish.category.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 8,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  dish.priceLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Форма бронирования ────────────────────────────────────────────────────────
class _BookingSheet extends StatefulWidget {
  const _BookingSheet();

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  int _guests = 2;
  String _zone = 'Главный зал';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _time = '19:00';

  static const _zones = ['Главный зал', 'Бар', 'Приватная комната', 'Терраса'];
  static const _times = ['12:00', '13:00', '14:00', '15:00', '16:00',
                          '17:00', '18:00', '19:00', '20:00', '21:00', '22:00'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _bg3,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: _glassB)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Забронировать стол',
                        style: GoogleFonts.outfit(
                          color: _txt,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Piligrim · Астана',
                        style: const TextStyle(color: _copperD, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: _glassB, height: 0.5),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding:
                    EdgeInsets.fromLTRB(22, 20, 22, botPad + 16),
                children: [
                  _BookingField(label: 'Ваше имя', ctrl: _nameCtrl, hint: 'Айгерим'),
                  const SizedBox(height: 14),
                  _BookingField(
                    label: 'Телефон',
                    ctrl: _phoneCtrl,
                    hint: '+7 (___) ___-__-__',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  // Date + Time row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(label: 'Дата'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                      const Duration(days: 180)),
                                  builder: (ctx, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF7BA5B8),
                                        surface: Color(0xFF2A2826),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _date = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: _bg1,
                                  border: Border.all(color: _glassB),
                                ),
                                child: Row(
                                  children: [
                                    const Text('◌',
                                        style: TextStyle(fontSize: 16, color: _copperD, height: 1.0)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_date.day.toString().padLeft(2, '0')}.'
                                      '${_date.month.toString().padLeft(2, '0')}.'
                                      '${_date.year}',
                                      style: const TextStyle(
                                          color: _txt, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(label: 'Время'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _bg1,
                                border: Border.all(color: _glassB),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _time,
                                  dropdownColor: _bg1,
                                  iconEnabledColor: _copperD,
                                  style: const TextStyle(
                                      color: _txt, fontSize: 13),
                                  items: _times
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _time = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Guests
                  _FieldLabel(label: 'Количество гостей'),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(6, (i) {
                      final n = i + 1;
                      final sel = n == _guests;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _guests = n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: sel
                                  ? _copper.withValues(alpha: 0.18)
                                  : _bg1,
                              border: Border.all(
                                color: sel ? _copper : _glassB,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: _ember.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  color: sel ? _copper : _txtMid,
                                  fontSize: 15,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  // Zone
                  _FieldLabel(label: 'Зона / зал'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _zones.map((z) {
                      final sel = z == _zone;
                      return GestureDetector(
                        onTap: () => setState(() => _zone = z),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: sel
                                ? _copper.withValues(alpha: 0.15)
                                : _bg1,
                            border:
                                Border.all(color: sel ? _copper : _glassB),
                          ),
                          child: Text(
                            z,
                            style: TextStyle(
                              color: sel ? _copper : _txtMid,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _BookingField(
                    label: 'Комментарий',
                    ctrl: _noteCtrl,
                    hint: 'Повод, пожелания, аллергии...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  // Submit
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Заявка принята! Мы свяжемся с вами в течение 15 минут. Удачного вам пути.',
                            style: TextStyle(color: _txt, fontSize: 13),
                          ),
                          backgroundColor: _bg1,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _fruit,
                        boxShadow: [
                          BoxShadow(
                            color: _fruit.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'ОТПРАВИТЬ ЗАЯВКУ',
                        style: GoogleFonts.outfit(
                          color: _txt,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _BookingField({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: _txt, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _txtDim),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _glassB),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _glassB),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _copper.withValues(alpha: 0.7)),
            ),
            fillColor: _bg1,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _copperD,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// МЕНЮ (видео-лента + классика)
// ══════════════════════════════════════════════════════════════════════════════
class _MenuTab extends StatefulWidget {
  const _MenuTab();

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  bool _tikTok = true;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        _tikTok
            ? const TikTokMenuView()
            : _ClassicMenuView(topPad: topPad),
        // Mode toggle (top-right, overlaid)
        Positioned(
          top: topPad + 10,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => _tikTok = !_tikTok),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(color: _copper.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tikTok ? '≡' : '▶',
                    style: const TextStyle(fontSize: 13, color: _copper, height: 1.0),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _tikTok ? 'Классика' : 'Видео-лента',
                    style: const TextStyle(
                      color: _copper,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Классическое меню ─────────────────────────────────────────────────────────
class _ClassicMenuView extends StatefulWidget {
  final double topPad;
  const _ClassicMenuView({required this.topPad});

  @override
  State<_ClassicMenuView> createState() => _ClassicMenuViewState();
}

class _ClassicMenuViewState extends State<_ClassicMenuView> {
  String _cat = 'Все';
  static const _cats = ['Все', 'Супы', 'Холодное', 'Горячее', 'Десерты', 'Напитки', 'Вино'];

  @override
  Widget build(BuildContext context) {
    final filtered = _cat == 'Все'
        ? kMockMenuDishes
        : kMockMenuDishes.where((d) => d.category == _cat).toList();

    return Container(
      color: _bg4,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
                top: widget.topPad + 12,
                left: 20,
                right: 20,
                bottom: 14),
            decoration: const BoxDecoration(
              color: _bg4,
              border: Border(bottom: BorderSide(color: _glassB, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Меню',
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final active = _cats[i] == _cat;
                      return Padding(
                        padding: EdgeInsets.only(
                            right: i < _cats.length - 1 ? 6 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _cat = _cats[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: active
                                  ? _copper.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              border: Border.all(
                                color: active
                                    ? _copper.withValues(alpha: 0.6)
                                    : _glassB,
                              ),
                            ),
                            child: Text(
                              _cats[i].toUpperCase(),
                              style: TextStyle(
                                color: active ? _copper : _txtDim,
                                fontSize: 9,
                                letterSpacing: 0.8,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClassicDishRow(dish: filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassicDishRow extends StatelessWidget {
  final MockMenuDish dish;
  const _ClassicDishRow({required this.dish});

  static const _accents = {
    'Супы':     Color(0xFFC4956A),   // Сары дала
    'Холодное': Color(0xFF7BA5B8),   // Мөлдір су
    'Горячее':  Color(0xFFC4956A),   // Сары дала
    'Десерты':  Color(0xFFD4B080),   // Сары дала светлый
    'Напитки':  Color(0xFF7BA5B8),   // Мөлдір су
    'Вино':     Color(0xFF8B3A3A),   // Піскен жеміс derived
  };

  @override
  Widget build(BuildContext context) {
    final c = _accents[dish.category] ?? _copper;

    return Container(
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  _catSymbol(dish.category),
                  style: TextStyle(fontSize: 20, color: c.withValues(alpha: 0.8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dish.description,
                    style: const TextStyle(
                        color: _txtDim, fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dish.priceLabel,
                    style: TextStyle(
                        color: c, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _catSymbol(String cat) {
    const s = {
      'Супы': '◈', 'Холодное': '◇', 'Горячее': '✦',
      'Десерты': '✧', 'Напитки': '◆', 'Вино': '❖',
    };
    return s[cat] ?? '✦';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ИНТЕРЬЕР
// ══════════════════════════════════════════════════════════════════════════════
// ── Модель зоны интерьера ─────────────────────────────────────────────────────
class _IZone {
  final String name;
  final String nameKz;
  final String description;
  final String story;
  final List<String> materials;
  final Color primary;
  final Color accent;
  final String symbol;
  final List<Color> gradientColors;

  const _IZone({
    required this.name,
    required this.nameKz,
    required this.description,
    required this.story,
    required this.materials,
    required this.primary,
    required this.accent,
    required this.symbol,
    required this.gradientColors,
  });
}

const _kIZones = <_IZone>[
  _IZone(
    name: 'Главный зал',
    nameKz: 'Басты зал',
    description: 'Сердце ресторана. Открытое, живое, дышащее.',
    story:
        'Главный зал объединяет три стихии: земля под ногами, '
        'огонь в центре, вода в текстурах меди. Каждый элемент — '
        'продолжение легенды о пути героя.',
    materials: ['Дерево саксаула', 'Медь с патиной', 'Натуральный камень'],
    primary: Color(0xFF1A1410),
    accent: Color(0xFFC4956A),
    symbol: '◈',
    gradientColors: [Color(0xFF2A1F14), Color(0xFF1A1410), Color(0xFF0E0C09)],
  ),
  _IZone(
    name: 'Бар',
    nameKz: 'Бар',
    description: 'Тёмный камень, отсвет воды, запах трав.',
    story:
        'Место где герой делает паузу перед следующим этапом пути. '
        'Тёмный мрамор контрастирует с тёплым светом. '
        'Каждый напиток — часть гастрономического ритуала.',
    materials: ['Чёрный мрамор', 'Латунь', 'Тёмное стекло'],
    primary: Color(0xFF0E1218),
    accent: Color(0xFF7BA5B8),
    symbol: '◆',
    gradientColors: [Color(0xFF0E1520), Color(0xFF080C14), Color(0xFF040608)],
  ),
  _IZone(
    name: 'Приватная комната',
    nameKz: 'Жеке бөлме',
    description: 'Закрытое пространство для восьми героев.',
    story:
        'Интимное пространство, где время замедляется. '
        'Природные текстуры, тишина. Идеальное место для '
        'переговоров или особого торжества.',
    materials: ['Кожа ручной выделки', 'Необработанное дерево', 'Войлок'],
    primary: Color(0xFF161510),
    accent: Color(0xFFC4956A),
    symbol: '◇',
    gradientColors: [Color(0xFF201A0C), Color(0xFF140F08), Color(0xFF0A0804)],
  ),
  _IZone(
    name: 'Терраса АУА',
    nameKz: 'АУА терраса',
    description: 'Открытое небо. Горизонт степи.',
    story:
        'АУА — воздух на казахском. Пространство под открытым небом '
        'Астаны, где аромат живого огня смешивается с прохладой ночи.',
    materials: ['Открытое небо', 'Живой огонь', 'Натуральные ткани'],
    primary: Color(0xFF0E1520),
    accent: Color(0xFF7BA5B8),
    symbol: '✦',
    gradientColors: [Color(0xFF0E1828), Color(0xFF080F1A), Color(0xFF040810)],
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// ВКЛАДКА ИНТЕРЬЕР
// ══════════════════════════════════════════════════════════════════════════════

class _InteriorTab extends StatefulWidget {
  const _InteriorTab();

  @override
  State<_InteriorTab> createState() => _InteriorTabState();
}

class _InteriorTabState extends State<_InteriorTab>
    with TickerProviderStateMixin {
  int _selectedZone = 0;
  bool _audioOn = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final AnimationController _zoneCtrl;
  late final Animation<double> _zoneFade;
  late final Animation<Offset> _zoneSlide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic);
    _fadeCtrl.forward();

    _zoneCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _zoneFade =
        CurvedAnimation(parent: _zoneCtrl, curve: Curves.easeInOutCubic);
    _zoneSlide =
        Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero).animate(
            CurvedAnimation(parent: _zoneCtrl, curve: Curves.easeInOutCubic));
    _zoneCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  void _selectZone(int i) {
    if (i == _selectedZone) return;
    _zoneCtrl.reset();
    setState(() => _selectedZone = i);
    _zoneCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final zone = _kIZones[_selectedZone];
    return Container(
      color: _bg4,
      child: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Immersive hero ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _InteriorHero(
                audioOn: _audioOn,
                onAudioToggle: () => setState(() => _audioOn = !_audioOn),
              ),
            ),

            // ── Zone selector tabs ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ZoneSelector(
                  selected: _selectedZone, onSelect: _selectZone),
            ),

            // ── Selected zone detail ────────────────────────────────────────
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _zoneSlide,
                child: FadeTransition(
                  opacity: _zoneFade,
                  child: _ZoneDetail(zone: zone),
                ),
              ),
            ),

            // ── Photo gallery with tap hints (per TZ) ───────────────────────
            SliverToBoxAdapter(
              child: _ZonePhotoGallery(
                zoneIndex: _selectedZone,
                zone: zone,
              ),
            ),

            // ── Materials strip ─────────────────────────────────────────────
            const SliverToBoxAdapter(child: _MaterialsStrip()),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────
class _InteriorHero extends StatefulWidget {
  final bool audioOn;
  final VoidCallback onAudioToggle;

  const _InteriorHero({required this.audioOn, required this.onAudioToggle});

  @override
  State<_InteriorHero> createState() => _InteriorHeroState();
}

class _InteriorHeroState extends State<_InteriorHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, _) {
        return SizedBox(
          height: 380,
          child: Stack(
            children: [
              // ── Atmospheric canvas
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeroPainter(glowValue: _glowCtrl.value),
                ),
              ),

              // ── Totem watermark
              Positioned(
                right: -24,
                bottom: 24,
                child: Opacity(
                  opacity: 0.035,
                  child: Text('◈',
                      style: TextStyle(fontSize: 230, color: _ember)),
                ),
              ),

              // ── Петроглиф — декоративные концентрические круги
              Positioned(
                left: -30,
                top: 80,
                child: Opacity(
                  opacity: 0.06,
                  child: CustomPaint(
                    size: const Size(160, 160),
                    painter: _PetroglyphPainter(
                        pulse: _glowCtrl.value, color: _copper),
                  ),
                ),
              ),

              // ── Gradient fade bottom → bg
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _bg4.withValues(alpha: 0.5),
                        _bg4,
                      ],
                      stops: const [0.4, 0.72, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 2.5,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [_ember, _copper],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'ИНТЕРЬЕР',
                            style: GoogleFonts.outfit(
                              color: _txt,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Text(
                          'Пространства, где живёт история',
                          style: GoogleFonts.outfit(
                            color: _txtDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Audio ambient toggle
                      GestureDetector(
                        onTap: widget.onAudioToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: widget.audioOn
                                ? _copper.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: widget.audioOn
                                  ? _copper.withValues(alpha: 0.6)
                                  : _glassB,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.audioOn ? '◈' : '◌',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.audioOn ? _copper : _txtDim,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.audioOn
                                    ? 'Амбиент включён'
                                    : 'Атмосферный звук',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: widget.audioOn ? _copper : _txtDim,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Top badge: кол-во зон
              Positioned(
                top: topPad + 14,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: _glassB),
                  ),
                  child: Text(
                    '${_kIZones.length} зоны',
                    style: GoogleFonts.outfit(
                      color: _txtMid,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Hero Painter ─────────────────────────────────────────────────────────────
class _HeroPainter extends CustomPainter {
  final double glowValue;
  const _HeroPainter({required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1510), Color(0xFF0E0C09), Color(0xFF080604)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Copper fire glow (bottom-left)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, 0.9),
          radius: 0.75,
          colors: [
            Color.fromRGBO(196, 149, 106, 0.18 + glowValue * 0.14),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Steel-blue glow (top-right)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, -0.4),
          radius: 0.55,
          colors: [
            Color.fromRGBO(123, 165, 184, 0.10 + glowValue * 0.07),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Horizontal wood-grain texture lines
    final linePaint = Paint()..strokeWidth = 0.7;
    for (int i = 0; i < 28; i++) {
      linePaint.color =
          Color.fromRGBO(196, 149, 106, 0.025 + (i % 3 == 0 ? 0.015 : 0));
      final y = size.height * i / 28;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Diagonal accent line (architectural)
    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width, size.height * 0.38),
      Paint()
        ..color = const Color.fromRGBO(196, 149, 106, 0.07)
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width, size.height * 0.22),
      Paint()
        ..color = const Color.fromRGBO(123, 165, 184, 0.05)
        ..strokeWidth = 0.6,
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.glowValue != glowValue;
}

// ── Petroglyph Painter (концентрические круги) ────────────────────────────────
class _PetroglyphPainter extends CustomPainter {
  final double pulse;
  final Color color;
  const _PetroglyphPainter({required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 5; i++) {
      paint.color = color.withValues(alpha: 0.6 - i * 0.1 + pulse * 0.05);
      canvas.drawCircle(Offset(cx, cy), i * 14.0 + pulse * 3, paint);
    }
    canvas.drawCircle(
        Offset(cx, cy), 3, Paint()..color = color.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(_PetroglyphPainter old) => old.pulse != pulse;
}

// ── Zone Selector ─────────────────────────────────────────────────────────────
class _ZoneSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _ZoneSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _kIZones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final zone = _kIZones[i];
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? zone.accent.withValues(alpha: 0.15)
                    : _bg1.withValues(alpha: 0.6),
                border: Border.all(
                  color: active
                      ? zone.accent.withValues(alpha: 0.55)
                      : _glassB,
                  width: active ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                        fontSize: 13,
                        color: active ? zone.accent : _txtDim),
                    child: Text(zone.symbol),
                  ),
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight:
                          active ? FontWeight.w500 : FontWeight.w300,
                      color: active ? zone.accent : _txtDim,
                      letterSpacing: 0.3,
                    ),
                    child: Text(zone.name),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Zone Detail ───────────────────────────────────────────────────────────────
class _ZoneDetail extends StatelessWidget {
  final _IZone zone;
  const _ZoneDetail({required this.zone});

  @override
  Widget build(BuildContext context) {
    final idx = _kIZones.indexOf(zone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // ── Atmospheric visual card
          Container(
            height: 268,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: zone.accent.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Atmospheric painted background
                  CustomPaint(painter: _ZonePainter(zone: zone)),

                  // Large totem watermark
                  Positioned(
                    right: -22,
                    top: -22,
                    child: Text(
                      zone.symbol,
                      style: TextStyle(
                        fontSize: 190,
                        color: zone.accent.withValues(alpha: 0.055),
                        height: 1.0,
                      ),
                    ),
                  ),

                  // Zone number
                  Positioned(
                    top: 18,
                    left: 20,
                    child: Text(
                      '0${idx + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        color: zone.accent.withValues(alpha: 0.12),
                        height: 1.0,
                      ),
                    ),
                  ),

                  // Petroglyph decoration (top-right)
                  Positioned(
                    top: 12,
                    right: 20,
                    child: Opacity(
                      opacity: 0.12,
                      child: CustomPaint(
                        size: const Size(60, 60),
                        painter: _PetroglyphPainter(pulse: 0, color: zone.accent),
                      ),
                    ),
                  ),

                  // Bottom gradient + text
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            zone.primary.withValues(alpha: 0.6),
                            zone.primary,
                          ],
                          stops: const [0.28, 0.62, 1.0],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kazakh name badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: zone.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: zone.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              zone.nameKz,
                              style: GoogleFonts.outfit(
                                color: zone.accent.withValues(alpha: 0.9),
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            zone.name,
                            style: GoogleFonts.outfit(
                              color: _txt,
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            zone.description,
                            style: GoogleFonts.outfit(
                              color: _txtMid,
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Story + materials card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _bg1.withValues(alpha: 0.8),
              border: Border.all(color: _glassB),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Story section header
                Row(
                  children: [
                    Text('◈',
                        style: TextStyle(fontSize: 12, color: zone.accent)),
                    const SizedBox(width: 8),
                    Text(
                      'ИСТОРИЯ ПРОСТРАНСТВА',
                      style: GoogleFonts.outfit(
                        color: zone.accent.withValues(alpha: 0.8),
                        fontSize: 9.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  zone.story,
                  style: GoogleFonts.outfit(
                    color: _txtMid,
                    fontSize: 14,
                    height: 1.68,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 20),

                // Divider
                Container(height: 0.5, color: _glassB),
                const SizedBox(height: 16),

                // Materials section
                Row(
                  children: [
                    Text('✦',
                        style: TextStyle(fontSize: 10, color: _ember)),
                    const SizedBox(width: 8),
                    Text(
                      'МАТЕРИАЛЫ',
                      style: GoogleFonts.outfit(
                        color: _ember.withValues(alpha: 0.8),
                        fontSize: 9.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: zone.materials.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _ember.withValues(alpha: 0.07),
                        border: Border.all(
                            color: _ember.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        m,
                        style: GoogleFonts.outfit(
                          color: _ember.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zone custom painter ────────────────────────────────────────────────────────
class _ZonePainter extends CustomPainter {
  final _IZone zone;
  const _ZonePainter({required this.zone});

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: zone.gradientColors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Radial glow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, -0.3),
          radius: 0.85,
          colors: [
            zone.accent.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Horizontal texture lines
    final lp = Paint()..strokeWidth = 0.7;
    for (int i = 0; i < 22; i++) {
      lp.color = zone.accent.withValues(alpha: 0.04 + (i % 4 == 0 ? 0.02 : 0));
      final y = size.height * i / 22;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    }

    // Diagonal architectural accent
    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width, size.height * 0.42),
      Paint()
        ..color = zone.accent.withValues(alpha: 0.1)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ZonePainter old) => false;
}

// ── Zone grid card (unused — kept for reference) ──────────────────────────────
// ignore: unused_element
class _ZoneGridCard extends StatelessWidget {
  final _IZone zone;
  final bool selected;
  final int index;

  const _ZoneGridCard({
    required this.zone,
    required this.selected,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? zone.accent.withValues(alpha: 0.6)
              : _glassB,
          width: selected ? 1.5 : 0.8,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: zone.accent.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ZonePainter(zone: zone)),

            // Watermark symbol
            Positioned(
              right: -8,
              bottom: -8,
              child: Text(
                zone.symbol,
                style: TextStyle(
                  fontSize: 76,
                  color: zone.accent.withValues(alpha: 0.07),
                  height: 1.0,
                ),
              ),
            ),

            // Selected dot
            if (selected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: zone.accent,
                    boxShadow: [
                      BoxShadow(
                        color: zone.accent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    zone.symbol,
                    style: TextStyle(
                      fontSize: 20,
                      color: zone.accent.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    zone.name,
                    style: GoogleFonts.outfit(
                      color: _txt,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    zone.nameKz,
                    style: GoogleFonts.outfit(
                      color: zone.accent.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo gallery hint data (per TZ: подсказки на тур-точках) ────────────────
const _kZoneHints = <int, List<(String, String)>>{
  0: [
    ('Центральный очаг', 'Открытый живой огонь в центре зала. Не декор — первоэлемент, вокруг которого строится весь интерьер.'),
    ('Потолок', 'Деревянные балки воспроизводят купольную конструкцию юрты — символ крова странника.'),
    ('Пол', 'Каменные плиты из месторождений Центрального Казахстана. Каждая — уникальный природный узор.'),
    ('Стены', 'Саксауловые панели ручной обработки. Дерево везли из Кызылординской степи — выдержанное, почти окаменевшее.'),
  ],
  1: [
    ('Стойка бара', 'Столешница из слэба саксаула с эпоксидной заливкой. Срез дерева как хроника времени.'),
    ('Стена', 'Стеллаж из окисленной латуни — экспозиция артефактов путника, найденных в пути.'),
    ('Освещение', 'Медные подвесы ручной ковки. Каждый светильник единственный — тиражирование исключено.'),
  ],
  2: [
    ('Стены', 'Кожаные панели горной выделки в технике пэтчворк. Каждый фрагмент — отдельная история.'),
    ('Стол', 'Слэб мрамора из карьеров Восточного Казахстана на кованых металлических ногах. Вес — 340 кг.'),
    ('Атмосфера', 'Скрытая подсветка в нишах. Мягкий направленный свет — как у угасающего костра.'),
  ],
  3: [
    ('Панорама', 'Вид на горизонт Астаны. Каждый стол открывает свою уникальную точку обзора.'),
    ('Настил', 'Термодерево устойчиво к морозам −40°С и летней жаре +40°С Казахстана.'),
    ('Биокамины', 'Уличные биокамины поддерживают тепло и живой огонь даже в прохладные вечера.'),
  ],
};

// ── Zone Photo Gallery (TZ: галерея по зонам с подсказками) ──────────────────
class _ZonePhotoGallery extends StatefulWidget {
  final int zoneIndex;
  final _IZone zone;
  const _ZonePhotoGallery({required this.zoneIndex, required this.zone});

  @override
  State<_ZonePhotoGallery> createState() => _ZonePhotoGalleryState();
}

class _ZonePhotoGalleryState extends State<_ZonePhotoGallery> {
  int? _expanded;

  @override
  void didUpdateWidget(_ZonePhotoGallery old) {
    super.didUpdateWidget(old);
    if (old.zoneIndex != widget.zoneIndex) _expanded = null;
  }

  @override
  Widget build(BuildContext context) {
    final hints = _kZoneHints[widget.zoneIndex] ?? [];
    final zone = widget.zone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [zone.accent, zone.accent.withValues(alpha: 0.3)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ГАЛЕРЕЯ',
                style: GoogleFonts.outfit(
                  color: _txtDim,
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                '◌ нажми для описания',
                style: GoogleFonts.outfit(
                  color: _txtDim.withValues(alpha: 0.45),
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable photo cards
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: hints.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (title, desc) = hints[i];
              final isExp = _expanded == i;
              return GestureDetector(
                onTap: () => setState(() => _expanded = isExp ? null : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: isExp ? 252 : 148,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExp
                          ? zone.accent.withValues(alpha: 0.55)
                          : _glassB,
                      width: isExp ? 1.2 : 0.8,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Painted zone background
                        CustomPaint(painter: _ZonePainter(zone: zone)),

                        // Tap icon (top-right)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isExp ? '◈' : '◌',
                              key: ValueKey(isExp),
                              style: TextStyle(
                                fontSize: 14,
                                color: isExp
                                    ? zone.accent
                                    : zone.accent.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),

                        // Photo spot number
                        Positioned(
                          top: 10,
                          left: 14,
                          child: Text(
                            '0${i + 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: zone.accent.withValues(alpha: 0.10),
                              height: 1.0,
                            ),
                          ),
                        ),

                        // Bottom gradient + content
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  zone.primary.withValues(alpha: 0.5),
                                  zone.primary,
                                ],
                                stops: const [0.3, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    color: _txt,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOutCubic,
                                  child: isExp
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            desc,
                                            style: GoogleFonts.outfit(
                                              color: _txtMid,
                                              fontSize: 11,
                                              height: 1.45,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Materials strip ────────────────────────────────────────────────────────────
const _kMaterials = <(String, String, Color)>[
  ('Дерево саксаула', 'Высушенное в степи', Color(0xFFC4956A)),
  ('Медь', 'С патиной времени', Color(0xFF7BA5B8)),
  ('Натуральный камень', 'Горные породы', Color(0xFF9A8F80)),
  ('Кожа', 'Ручная обработка', Color(0xFFC4956A)),
  ('Войлок', 'Кочевнический мотив', Color(0xFF7BA5B8)),
];

class _MaterialsStrip extends StatelessWidget {
  const _MaterialsStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            children: [
              Container(
                  width: 2,
                  height: 16,
                  color: _ember.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Text(
                'МАТЕРИАЛЫ И ТЕКСТУРЫ',
                style: GoogleFonts.outfit(
                  color: _txtDim,
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kMaterials.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (name, sub, color) = _kMaterials[i];
              return Container(
                width: 134,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _bg1,
                  border: Border.all(
                      color: color.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('◈',
                        style: TextStyle(
                            fontSize: 14,
                            color: color.withValues(alpha: 0.55))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            color: _txt,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          sub,
                          style: GoogleFonts.outfit(
                            color: _txtDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// АФИША
// ══════════════════════════════════════════════════════════════════════════════
class _PEvent {
  final String title;
  final String subtitle;
  final String date;
  final String time;
  final String price;
  final bool closed;

  const _PEvent({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    required this.price,
    required this.closed,
  });
}

const _kEvents = <_PEvent>[
  _PEvent(
    title: 'Вечер джаза в медной тишине',
    subtitle: 'Квартет Азиза Омарова',
    date: '10 мая',
    time: '20:00',
    price: '2 000 ₸',
    closed: false,
  ),
  _PEvent(
    title: 'Дегустация казахстанских вин',
    subtitle: 'Шеф-сомелье Андрей Смирнов · 6 вин',
    date: '17 мая',
    time: '19:00',
    price: '5 000 ₸',
    closed: false,
  ),
  _PEvent(
    title: 'Закрытый ужин с шефом',
    subtitle: 'Только 8 гостей · Авторское меню',
    date: '24 мая',
    time: '18:30',
    price: '15 000 ₸',
    closed: true,
  ),
  _PEvent(
    title: 'Номадский завтрак',
    subtitle: 'Традиционные блюда в современном прочтении',
    date: '1 июня',
    time: '10:00',
    price: '4 500 ₸',
    closed: false,
  ),
];

class _EventsTab extends StatelessWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: _bg4,
      child: ListView(
        padding: EdgeInsets.only(top: topPad + 16, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'АФИША',
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Мероприятия и события Piligrim',
                  style: GoogleFonts.outfit(
                    color: _txtDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          ..._kEvents.map(
            (e) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _EventCard(event: e),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final _PEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    // Закрытые события — Піскен жеміс (тёмно-красный), открытые — Мөлдір су
    final accentColor = event.closed ? _fruit : _copper;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _bg1,
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: (event.closed ? _fruit : _ember)
                .withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glow streak
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    accentColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: accentColor.withValues(alpha: 0.12),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        event.date,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      event.time,
                      style: const TextStyle(color: _txtDim, fontSize: 12),
                    ),
                    const Spacer(),
                    if (event.closed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: _fruit.withValues(alpha: 0.15),
                        ),
                        child: Text(
                          'ЗАКРЫТОЕ',
                          style: TextStyle(
                            color: _fruit.withValues(alpha: 0.9),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style:
                      const TextStyle(color: _txtDim, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      event.price,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _register(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: accentColor.withValues(alpha: 0.12),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'Записаться',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _register(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventRegisterSheet(eventTitle: event.title),
    );
  }
}

// ── Форма записи на мероприятие ───────────────────────────────────────────────
class _EventRegisterSheet extends StatefulWidget {
  final String eventTitle;
  const _EventRegisterSheet({required this.eventTitle});

  @override
  State<_EventRegisterSheet> createState() => _EventRegisterSheetState();
}

class _EventRegisterSheetState extends State<_EventRegisterSheet> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Заявка на «${widget.eventTitle}» принята. Мы свяжемся с вами для подтверждения.',
          style: const TextStyle(color: _txt, fontSize: 13),
        ),
        backgroundColor: _bg1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg3,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: _glassB)),
        ),
        padding: EdgeInsets.fromLTRB(22, 16, 22, botPad + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Записаться',
              style: GoogleFonts.outfit(
                color: _txt,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.eventTitle,
              style: const TextStyle(color: _copperD, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _BookingField(label: 'Ваше имя', ctrl: _nameCtrl, hint: 'Айгерим'),
            const SizedBox(height: 14),
            _BookingField(
              label: 'Телефон',
              ctrl: _phoneCtrl,
              hint: '+7 (___) ___-__-__',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _copper,
                  boxShadow: [
                    BoxShadow(
                      color: _copper.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'ОТПРАВИТЬ ЗАЯВКУ',
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка события для главной (первое событие)
class _FeaturedEventCard extends StatelessWidget {
  final _PEvent event;
  const _FeaturedEventCard({required this.event});

  @override
  Widget build(BuildContext context) => _EventCard(event: event);
}

// ══════════════════════════════════════════════════════════════════════════════
// ПРОФИЛЬ
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: _bg4,
      child: ListView(
        padding: EdgeInsets.only(top: topPad + 16, bottom: 32),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ПРОФИЛЬ',
                  style: GoogleFonts.outfit(
                    color: _txt,
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Дорогие герои, добро пожаловать в PILIGRIM',
                  style: GoogleFonts.outfit(
                    color: _copperD,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Auth banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF282520), Color(0xFF1A1816)],
                ),
                border: Border.all(color: _glassB),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _copper.withValues(alpha: 0.12),
                      border: Border.all(color: _copperD),
                    ),
                    child:
                        const Text('◉', style: TextStyle(fontSize: 22, color: _copperD, height: 1.0)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Войти в аккаунт',
                            style: TextStyle(
                                color: _txt,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        const Text(
                          'Бронирования и уведомления',
                          style: TextStyle(color: _txtDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _copper.withValues(alpha: 0.12),
                      border: Border.all(color: _copper.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Войти',
                      style: TextStyle(
                          color: _copper, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Contacts
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SectionLabel(text: 'Контакты'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GlassCard(
              child: Column(
                children: [
                  _ContactRow(
                    symbol: '◉',
                    label: 'Астана, пр. Туран 24',
                    accent: _copper,
                    onTap: () {},
                  ),
                  const _HLine(),
                  _ContactRow(
                    symbol: '◈',
                    label: '+7 777 777 77 77',
                    accent: _copper,
                    onTap: () {},
                  ),
                  const _HLine(),
                  _ContactRow(
                    symbol: '⊕',
                    label: 'piligrimkitchen.com',
                    accent: _copper,
                    onTap: () {},
                  ),
                  const _HLine(),
                  _ContactRow(
                    symbol: '◇',
                    label: 'Telegram',
                    accent: _copper,
                    onTap: () {},
                  ),
                  const _HLine(),
                  _ContactRow(
                    symbol: '⋄',
                    label: 'WhatsApp',
                    accent: _ember,
                    onTap: () {},
                  ),
                  const _HLine(),
                  _ContactRow(
                    symbol: '✦',
                    label: '@piligrim.astana',
                    accent: _ember,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Hours
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SectionLabel(text: 'Часы работы'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GlassCard(
              child: Column(
                children: const [
                  _HoursRow(days: 'Пн — Пт', time: '12:00 — 23:00'),
                  _HLine(),
                  _HoursRow(days: 'Сб — Вс', time: '11:00 — 00:00'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Push notifications
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SectionLabel(text: 'Уведомления'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GlassCard(
              child: Column(
                children: [
                  _ToggleRow(symbol: '☽', label: 'Мероприятия', initialOn: true),
                  const _HLine(),
                  _ToggleRow(symbol: '✦', label: 'Акции и предложения', initialOn: true),
                  const _HLine(),
                  _ToggleRow(symbol: '◇', label: 'Закрытые события', initialOn: false),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Legal / About
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SectionLabel(text: 'Ещё'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GlassCard(
              child: Column(
                children: [
                  _LinkRow(label: 'Правила посещения'),
                  const _HLine(),
                  _LinkRow(label: 'Обратная связь'),
                  const _HLine(),
                  _LinkRow(label: 'Пользовательское соглашение'),
                  const _HLine(),
                  _LinkRow(label: 'Политика конфиденциальности'),
                  const _HLine(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text('Версия', style: TextStyle(color: _txtDim, fontSize: 13)),
                        Spacer(),
                        Text('1.0.0', style: TextStyle(color: _txtDim, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String symbol;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ContactRow({
    required this.symbol,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Text(symbol, style: TextStyle(fontSize: 18, color: accent, height: 1.0)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _txtMid, fontSize: 14)),
            ),
            const Text('›', style: TextStyle(fontSize: 20, color: _txtDim, height: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String days;
  final String time;

  const _HoursRow({required this.days, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(days, style: const TextStyle(color: _txtMid, fontSize: 14)),
          const Spacer(),
          Text(time,
              style: const TextStyle(
                  color: _copper,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  const _LinkRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: _txtMid, fontSize: 14)),
          ),
          const Text('›', style: TextStyle(fontSize: 20, color: _txtDim, height: 1.0)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final String symbol;
  final String label;
  final bool initialOn;

  const _ToggleRow({required this.symbol, required this.label, required this.initialOn});

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.initialOn;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(widget.symbol, style: const TextStyle(fontSize: 18, color: _copperD, height: 1.0)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.label,
                style: const TextStyle(color: _txtMid, fontSize: 14)),
          ),
          GestureDetector(
            onTap: () => setState(() => _on = !_on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _on ? _copper.withValues(alpha: 0.22) : Colors.white10,
                border: Border.all(
                    color: _on ? _copperD : Colors.white12),
                boxShadow: _on
                    ? [BoxShadow(color: _ember.withValues(alpha: 0.35), blurRadius: 6)]
                    : null,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    _on ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _on ? _copper : const Color(0xFF4A4A4A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Общие компоненты
// ══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '✦',
          style: TextStyle(
            color: _copper.withValues(alpha: 0.65),
            fontSize: 9,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: _copperD,
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_copperD, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _glassB),
      ),
      child: child,
    );
  }
}

class _HLine extends StatelessWidget {
  const _HLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(height: 0.5, child: ColoredBox(color: _glassB)),
    );
  }
}
