// Согласно piligrim_design_spec.md — вся цветовая система и типографика бренда PILIGRIM
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ЦВЕТА БРЕНДА (названы по-казахски — часть идентичности)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimColors {
  /// Қара жер — Чёрная земля — основной тёмный фон
  static const Color earth = Color(0xFF1C1814);

  /// Қара жер (глубокий) — фон навбара, более тёмный слой
  static const Color earthDeep = Color(0xFF141210);

  /// Қара жер (тёплый) — утеплённый базовый фон для «Живого очага»
  static const Color earthWarm = Color(0xFF252018);

  /// Мөлдір су — Прозрачная вода — главный акцентный цвет
  static const Color water = Color(0xFF7BA5B8);

  /// Мөлдір су (pressed) — нажатое состояние акцента
  static const Color waterMuted = Color(0xFF5A8FA8);

  /// Сары дала — Жёлтая степь — тёплый второстепенный акцент
  static const Color steppe = Color(0xFFC4956A);

  /// Піскен жеміс — Спелый плод — красный, CTA финального действия
  static const Color fruit = Color(0xFF8B1A1A);

  /// Жалын — Огонь — медно-оранжевый, мотив огня на активных CTA
  /// Согласно ТЗ: «мягкие переходы оранжевого по краю активных кнопок»
  static const Color ember = Color(0xFFC87340);

  /// Жалын (тёмный) — тёмно-медный, для градиентных кнопок
  static const Color emberDeep = Color(0xFF9A4E22);

  /// Modern Nomad Premium — мягкий крем (вместо холодного белого)
  static const Color nomadCream = Color(0xFFE0D8CC);

  /// Ақ аспан — светлый акцент на тёмном (крем luxury)
  static const Color sky = nomadCream;

  /// Ақ аспан (тёплый) — чуть глубже для вторичных светлых плоскостей
  static const Color skyWarm = Color(0xFFD4CABF);

  /// Разделители на тёмном фоне
  static const Color divider = Color(0x24E0D8CC);

  /// Текст на тёмном фоне
  static const Color textLight = nomadCream;

  /// Текст на светлом фоне
  static const Color textDark = Color(0xFF3D3A38);

  /// Неактивные элементы навигации
  static const Color navInactive = Color(0x8FE0D8CC);

  /// Прозрачный служебный цвет (вместо Colors.transparent)
  static const Color clear = Color(0x00000000);

  /// Базовый цвет тени (вместо Colors.black)
  static const Color shadow = Color(0xFF000000);

  // ─── Scaffold / оверлей ───

  /// Чуть теплее earth — scaffold-фон под параллакс-слоями
  static const Color earthSurface = Color(0xFF1E1B19);

  // ─── Навигационный бар ───

  /// Нижняя навбар — основной фон
  static const Color navBarBase = Color(0xFF211D1A);

  /// Нижняя навбар — верхний край градиента (чуть светлее)
  static const Color navBarTop = Color(0xFF2A2521);

  /// Нижняя навбар — верхняя кромка (тонкая светлая линия)
  static const Color navBarRim = Color(0x14F2EDE4);

  // ─── Теги меню (семантические цвета, согласованы с бекендом) ───

  /// Острое блюдо
  static const Color tagSpicy = Color(0xFFD4774A);

  /// Вегетарианское
  static const Color tagVegetarian = Color(0xFF7BAD7E);

  /// Содержит алкоголь
  static const Color tagAlcohol = Color(0xFF8B6A9F);

  /// Халяль
  static const Color tagHalal = Color(0xFF7BA5A0);
}

// ─────────────────────────────────────────────────────────────────────────────
// ШРИФТЫ (Museo Sans 300 / 700 — единственный UI-шрифт)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimFonts {
  static const String museoSans = 'MuseoSans';
}

// ─────────────────────────────────────────────────────────────────────────────
// ТЕКСТОВЫЕ СТИЛИ — согласно spec: Display/Title/Heading/Body/Caption/Button
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimTextStyles {
  // Display — широкий трекинг, характер заголовка (ТЗ: «шрифт с историческим оттенком»)
  // Компенсируем отсутствие второго шрифта через letterspacing + weight
  static const TextStyle display = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    height: 1.15,
    color: PiligrimColors.textLight,
    letterSpacing: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    color: PiligrimColors.textLight,
    letterSpacing: 1.2,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.3,
    color: PiligrimColors.textLight,
    letterSpacing: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w300,
    fontSize: 15,
    height: 1.6,
    color: PiligrimColors.textLight,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    height: 1.5,
    color: PiligrimColors.navInactive,
  );

  static const TextStyle button = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.0,
    letterSpacing: 0.08 * 15,
    color: PiligrimColors.textLight,
  );

  // ── Вынесенные повторяющиеся стили ──

  /// Компактный body (13px) — описания, подзаголовки, вторичный текст
  static const TextStyle bodySmall = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w300,
    fontSize: 13,
    height: 1.5,
    color: PiligrimColors.textLight,
  );

  /// Заголовок секции — CAPS, разрядка, приглушённый тон
  static TextStyle sectionLabel = const TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w300,
    fontSize: 10,
    height: 1.5,
    letterSpacing: 2.0,
    color: PiligrimColors.navInactive,
  );

  /// Текст CTA-кнопки (14px, sky, разрядка 1.2)
  static const TextStyle ctaLabel = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.0,
    letterSpacing: 1.2,
    color: PiligrimColors.textLight,
  );

  /// Микро-подписи (10px) — бейджи, метаданные, таймстемпы
  static const TextStyle micro = TextStyle(
    fontFamily: PiligrimFonts.museoSans,
    fontWeight: FontWeight.w300,
    fontSize: 10,
    height: 1.4,
    color: PiligrimColors.navInactive,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ТЕМА ПРИЛОЖЕНИЯ — тёмная (основная по брендбуку)
// ─────────────────────────────────────────────────────────────────────────────
final ThemeData piligrimTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: PiligrimColors.earth,
  splashColor: PiligrimColors.clear,
  highlightColor: PiligrimColors.clear,
  splashFactory: NoSplash.splashFactory,
  hoverColor: PiligrimColors.clear,
  colorScheme: const ColorScheme.dark(
    surface: PiligrimColors.earth,
    primary: PiligrimColors.steppe,
    secondary: PiligrimColors.ember,
    error: PiligrimColors.fruit,
    onSurface: PiligrimColors.textLight,
    onPrimary: PiligrimColors.textLight,
    onSecondary: PiligrimColors.textDark,
  ),
  fontFamily: PiligrimFonts.museoSans,
  textTheme: const TextTheme(
    displayLarge: PiligrimTextStyles.display,
    titleLarge: PiligrimTextStyles.title,
    titleMedium: PiligrimTextStyles.heading,
    bodyMedium: PiligrimTextStyles.body,
    bodySmall: PiligrimTextStyles.caption,
    labelLarge: PiligrimTextStyles.button,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: PiligrimColors.earth,
    foregroundColor: PiligrimColors.textLight,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Color(0x00000000),
    surfaceTintColor: Color(0x00000000),
    titleTextStyle: PiligrimTextStyles.heading,
    shape: RoundedRectangleBorder(
      side: BorderSide.none,
    ),
  ),
  dividerColor: PiligrimColors.divider,
  // ElevatedButton — тёплая медь/латунь согласно ТЗ «тёплые акценты»
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: PiligrimColors.steppe,
      foregroundColor: PiligrimColors.textLight,
      textStyle: PiligrimTextStyles.button,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shadowColor: PiligrimColors.ember,
      elevation: 8,
      splashFactory: NoSplash.splashFactory,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: PiligrimColors.steppe,
      side: const BorderSide(color: PiligrimColors.steppe, width: 1.0),
      textStyle: PiligrimTextStyles.button,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      splashFactory: NoSplash.splashFactory,
    ),
  ),
  cardTheme: CardThemeData(
    color: PiligrimColors.earthDeep,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: PiligrimColors.divider, width: 1),
    ),
    elevation: 0,
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// ОТСТУПЫ — базовая сетка 8px, 8×N
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  /// Горизонтальный padding секций
  static const double section = 24;
  /// Вертикальный gap между карточками
  static const double cardGap = 16;
}

// ─────────────────────────────────────────────────────────────────────────────
// СКРУГЛЕНИЯ — мягкая геометрия согласно design spec
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double card = 14;
  static const double lg = 20;

  static const Radius smR = Radius.circular(sm);
  static const Radius mdR = Radius.circular(md);
  static const Radius cardR = Radius.circular(card);
  static const Radius lgR = Radius.circular(lg);

  static const BorderRadius smAll = BorderRadius.all(smR);
  static const BorderRadius mdAll = BorderRadius.all(mdR);
  static const BorderRadius cardAll = BorderRadius.all(cardR);
  static const BorderRadius lgAll = BorderRadius.all(lgR);
}

// Текущая версия приложения — сравнивается с minVersion/latestVersion из API
const String kAppVersion = '1.0.0';
