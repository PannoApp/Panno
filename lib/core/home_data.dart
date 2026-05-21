// Данные для Home Screen — отделены от UI (Clean Architecture)
// UI читает только эти модели, не хардкодит строки/цвета/пути
import 'package:flutter/material.dart';
import 'theme.dart';

/// Открыть [BookingScreen] через Navigator.push, не tab.
const int kNavOpenBooking = -1;

// ─────────────────────────────────────────────────────────────────────────────
// Категории меню / разделы путешествия
// ─────────────────────────────────────────────────────────────────────────────
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.titleRu,
    required this.subtitle,
    required this.totemAsset,
    required this.accentColor,
    required this.navIndex,
    this.menuCategoryNameHint,
    this.badge,
  });

  final String id;
  final String titleRu;
  final String subtitle;
  final String totemAsset;
  final Color accentColor;
  /// Индекс вкладки RootShell или [kNavOpenBooking] для push BookingScreen.
  final int navIndex;
  /// Подстрока [ApiCategory.name] (RU) для фильтра при переходе с «Пути героя».
  final String? menuCategoryNameHint;
  final String? badge; // опциональный бейдж (например «NEW»)
}

/// Карточки пути: тотемы **не** те же SVG, что в [PiligrimNavBar], чтобы не путать с табами.
const kMenuCategories = [
  MenuCategory(
    id: 'start',
    titleRu: 'Начало пути',
    subtitle: 'Закуски',
    totemAsset: 'assets/images/spiral.svg',
    accentColor: PiligrimColors.water,
    navIndex: 1,
    menuCategoryNameHint: 'закуск',
  ),
  MenuCategory(
    id: 'main',
    titleRu: 'Основной путь',
    subtitle: 'Горячие блюда',
    totemAsset: 'assets/images/sun.svg',
    accentColor: PiligrimColors.steppe,
    navIndex: 1,
    menuCategoryNameHint: 'горяч',
  ),
  MenuCategory(
    id: 'events',
    titleRu: 'Ивент-спейс АУА',
    subtitle: 'Мероприятия',
    totemAsset: 'assets/images/pegasus.svg',
    accentColor: Color(0xFF9BB898), // приглушённый зелёный (природа, АУА)
    navIndex: 3,
    badge: 'СКОРО',
  ),
];

/// Быстрые действия под карточками «Путь героя»: тотемы **не** из [PiligrimNavBar].
class HeroPathFooterAction {
  const HeroPathFooterAction({
    required this.label,
    required this.subtitle,
    required this.totemAsset,
    required this.accentColor,
    required this.tabIndex,
    this.openMenuBrowseAll = false,
  });

  final String label;
  /// Короткая подпись шага (шёпот под заголовком).
  final String subtitle;
  final String totemAsset;
  final Color accentColor;
  /// Вкладка [RootShell] после действия.
  final int tabIndex;
  /// true: полное меню (лента), затем переход на вкладку меню.
  final bool openMenuBrowseAll;
}

/// Продолжение пути под карточками этапов — не дублирует тотемы навбара и карточек выше.
const kHeroPathFooterActions = [
  HeroPathFooterAction(
    label: 'Меню ресторана',
    subtitle: 'Вся кухня',
    totemAsset: 'assets/images/zerno.svg',
    accentColor: PiligrimColors.steppe,
    tabIndex: 1,
    openMenuBrowseAll: true,
  ),
  HeroPathFooterAction(
    label: 'Как добраться',
    subtitle: 'Маршрут',
    totemAsset: 'assets/images/splash_path (1).svg',
    accentColor: PiligrimColors.water,
    tabIndex: 4,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Ближайшее событие (в будущем — из API)
// ─────────────────────────────────────────────────────────────────────────────
class NearestEvent {
  const NearestEvent({
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.description,
    required this.tags,
  });

  final String title;
  final String dateLabel;
  final String timeLabel;
  final String description;
  final List<EventTag> tags;
}

class EventTag {
  const EventTag({required this.label, required this.iconAsset});
  final String label;
  final String iconAsset;
}

const kNearestEvent = NearestEvent(
  title: 'Вечер кюев\nи живой огонь',
  dateLabel: '24 МАЯ',
  timeLabel: '19:00',
  description:
      'Кобыз, шертер и традиционные блюда — вечер, где музыка и еда становятся одним путём.',
  tags: [
    EventTag(label: 'Живая музыка', iconAsset: 'assets/images/cobyz.svg'),
    EventTag(label: 'Авторское меню', iconAsset: 'assets/images/zerno.svg'),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Данные ресторана
// ─────────────────────────────────────────────────────────────────────────────
class RestaurantInfo {
  const RestaurantInfo({
    required this.openHour,
    required this.closeHour,
    required this.scheduleLabel,
  });

  final int openHour;
  final int closeHour;
  final String scheduleLabel;

  bool get isOpen {
    final h = DateTime.now().hour;
    return h >= openHour && h < closeHour;
  }

  String get hoursLabel => '$openHour:00 — $closeHour:00';
}

const kRestaurantInfo = RestaurantInfo(
  openHour: 12,
  closeHour: 23,
  scheduleLabel: 'Ежедневно',
);

// ─────────────────────────────────────────────────────────────────────────────
// Ротирующиеся слоганы Hero
// ─────────────────────────────────────────────────────────────────────────────
const kHeroPhrases = [
  'Вкус жизни.\nПуть героя.',
  'Дәстүрдің дәмі,\nеркіндік лебі.',
  'Кухня свободы\nи традиций.',
];

// ── ТЗ: краткое представление концепции Modern Nomad (1–2 фразы; brandbook)
const kModernNomadConcept =
    'Modern Nomad — герой между традицией и сегодняшним днём: аутентичный вкус '
    'и настроение Центральной Азии в тёплой, современной подаче PILIGRIM.';
