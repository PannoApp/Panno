// Согласно piligrim_design_spec.md — вся цветовая система и типографика бренда PILIGRIM
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ЦВЕТА БРЕНДА (названы по-казахски — часть идентичности)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class PiligrimColors {
  // ─── БАЗОВЫЕ ЗЕМЛИСТЫЕ ТОНА (Premium Obsidian & Clay) ───

  /// Қара жер — Чёрная земля — основной тёмный фон.
  /// Насыщенный обсидиановый уголь с тёплым подтоном сырой земли.
  static const Color earth = Color(0xFF15120F);

  /// Қара жер (глубокий) — фон навбара, глубочайший слой.
  /// Базальтовая бездна для максимального разделения слоев.
  static const Color earthDeep = Color(0xFF0E0C0B);

  /// Қара жер (тёплый) — утеплённый базовый фон для «Живого очага».
  /// Оттенок обжаренной глины, создающий уютное свечение.
  static const Color earthWarm = Color(0xFF201B18);

  /// Чуть теплее earth — scaffold-фон под параллакс-слоями.
  static const Color earthSurface = Color(0xFF181513);

  // ─── НАВИГАЦИОННЫЙ БАР (Obsidian Layers) ───

  /// Нижняя навбар — основной фон
  static const Color navBarBase = Color(0xFF13100E);

  /// Нижняя навбар — верхний край градиента
  static const Color navBarTop = Color(0xFF1E1A17);

  /// Нижняя навбар — верхняя кромка (тонкое премиальное свечение)
  static const Color navBarRim = Color(0x14F2ECE1);

  // ─── АКЦЕНТНЫЙ ГОЛУБОЙ (Glacier Turquoise) ───

  /// Мөлдір су — Прозрачная вода — главный акцентный цвет.
  /// Чистый минеральный бирюзово-голубой, ассоциирующийся с ледниками Тянь-Шаня.
  static const Color water = Color(0xFF659FB5);

  /// Мөлдір су (pressed) — нажатое состояние акцента.
  /// Более глубокий сланцево-синий оттенок.
  static const Color waterMuted = Color(0xFF4C7B8E);

  // ─── ВТОРОСТЕПЕННЫЕ И ТЕПЛЫЕ АКЦЕНТЫ (Champagne Gold & Copper) ───

  /// Сары дала — Жёлтая степь — тёплый второстепенный акцент.
  /// Благородная матовая латунь / шампанское золото вместо блеклой охры.
  static const Color steppe = Color(0xFFCFA073);

  /// Жалын — Огонь — медно-оранжевый, мотив огня на активных CTA.
  /// Живая светящаяся терракота для мягкого контраста.
  static const Color ember = Color(0xFFD9793E);

  /// Жалын (тёмный) — тёмно-медный, для градиентных кнопок.
  /// Выдержанная бронза.
  static const Color emberDeep = Color(0xFFB05D2A);

  /// Піскен жеміс — Спелый плод — красный, CTA финального действия.
  /// Глубокий гранатовый / рубиновый оттенок.
  static const Color fruit = Color(0xFFA63434);

  // ─── СВЕТЛЫЕ ТОНА И ТЕКСТ (Satin Alabaster & Silk Linen) ───

  /// Modern Nomad Premium — мягкий крем (вместо холодного белого).
  /// Шёлковый алебастр — чистый, дорогой светлый тон с едва заметным теплом.
  static const Color nomadCream = Color(0xFFF2ECE1);

  /// Ақ аспан — светлый акцент на тёмном (крем luxury)
  static const Color sky = nomadCream;

  /// Ақ аспан (тёплый) — чуть глубже для вторичных светлых плоскостей.
  /// Мягкий нежный лён.
  static const Color skyWarm = Color(0xFFDFD7CA);

  /// Разделители на тёмном фоне
  static const Color divider = Color(0x1FF2ECE1);

  /// Текст на тёмном фоне
  static const Color textLight = nomadCream;

  /// Текст на светлом фоне.
  /// Глубокий кофейно-базальтовый для идеальной читаемости.
  static const Color textDark = Color(0xFF2C2825);

  /// Неактивные элементы навигации
  static const Color navInactive = Color(0x8FF2ECE1);

  /// Прозрачный служебный цвет
  static const Color clear = Color(0x00000000);

  /// Базовый цвет тени
  static const Color shadow = Color(0xFF000000);

  // ─── ТЕГИ МЕНЮ (Gemstone Pastels, согласованные с бэкендом) ───

  /// Острое блюдо
  static const Color tagSpicy = Color(0xFFD67845);

  /// Вегетарианское
  static const Color tagVegetarian = Color(0xFF72A176);

  /// Содержит алкоголь
  static const Color tagAlcohol = Color(0xFF866E99);

  /// Халяль
  static const Color tagHalal = Color(0xFF6A9994);
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
