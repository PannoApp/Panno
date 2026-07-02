// Данные для Home Screen — отделены от UI (Clean Architecture)
// UI читает только эти модели, не хардкодит строки/цвета/пути

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
