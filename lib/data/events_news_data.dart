// Мок-данные афиши и новостей — ТЗ раздел «Афиша и новости»
// Цвета/тон: piligrim_design_spec.md (герой, без эмодзи)
import 'package:flutter/foundation.dart';

import '../core/interior_assets.dart';
import 'models/json_utils.dart';

/// Формат мероприятия: открытое / закрытое (ТЗ)
enum EventAccessFormat {
  open,
  closed,
}

extension EventAccessFormatX on EventAccessFormat {
  String get labelRu => switch (this) {
        EventAccessFormat.open => 'Открытое',
        EventAccessFormat.closed => 'Закрытое',
      };
}

@immutable
class PiligrimEvent {
  const PiligrimEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.format,
    required this.coverAssetPath,
    this.priceFromRub,
    this.isPast = false,
    this.hasPhotoReport = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final EventAccessFormat format;
  /// Обложка — атмосферные кадры интерьера (piligrim_design_spec.md §10)
  final String coverAssetPath;
  /// `null` — вход без фиксированной цены / по ситуации (не онлайн-продажа)
  final int? priceFromRub;
  final bool isPast;
  final bool hasPhotoReport;
}

@immutable
class PiligrimNewsPost {
  const PiligrimNewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final String? imageUrl;

  factory PiligrimNewsPost.fromJson(Map<String, dynamic> json) {
    return PiligrimNewsPost(
      id: parseInt(json['id'], field: 'id').toString(),
      title: parseString(json['title'], field: 'title'),
      body: parseString(json['content'] ?? json['body'], field: 'content'),
      publishedAt: parseDateTime(
        json['created_at'] ?? json['publishedAt'],
        field: 'created_at',
      ),
      imageUrl: parseStringOrNull(json['image'] ?? json['image_url']),
    );
  }
}

const _m1 = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String formatDateTimeRu(DateTime dt) {
  final m = _m1[dt.month - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} $m ${dt.year}, $hh:$mm';
}

String formatShortDateRu(DateTime dt) {
  final m = _m1[dt.month - 1];
  return '${dt.day} $m ${dt.year}';
}

/// Базовая дата «сегодня» для моков — от неё считаем ближайшие и прошедшие
DateTime _anchorToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

List<PiligrimEvent> buildMockEvents() {
  final t0 = _anchorToday();
  return [
    PiligrimEvent(
      id: 'e1',
      title: 'Вечер живой кобыза',
      description:
          'Импровизация на степных мотивах и дегустация блюд из печи. Пространство «АУА» — ивент-спейс Piligrim (piligrim_design_spec.md). Количество мест ограничено; запись не является покупкой билета — ресторан перезвонит для подтверждения.',
      startsAt: t0.add(const Duration(days: 3, hours: 19)),
      format: EventAccessFormat.open,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[0],
      priceFromRub: null,
    ),
    PiligrimEvent(
      id: 'e2',
      title: 'Закрытый ужин с шефом',
      description:
          'Сезонное меню из путешествия по Центральной Азии, вино и рассказ о традициях. Закрытый формат — список героев согласуется заранее.',
      startsAt: t0.add(const Duration(days: 8, hours: 19, minutes: 30)),
      format: EventAccessFormat.closed,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[1],
      priceFromRub: 18500,
    ),
    PiligrimEvent(
      id: 'e3',
      title: 'Мастер-класс: тесто и очаг',
      description:
          'Работа с тестом в стиле кочевой кухни, выпечка на открытом огне. Подходит героям с любым опытом.',
      startsAt: t0.add(const Duration(days: 14, hours: 16)),
      format: EventAccessFormat.open,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[2],
      priceFromRub: 4500,
    ),
    PiligrimEvent(
      id: 'e4',
      title: 'Ночь длинных столов',
      description:
          'Совместный стол на террасе, свечи и меню на выбор проводника. Тёплая атмосфера без спешки.',
      startsAt: t0.add(const Duration(days: 21, hours: 20)),
      format: EventAccessFormat.open,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[0],
      priceFromRub: null,
    ),
    PiligrimEvent(
      id: 'p1',
      title: 'Весеннее равноденствие — ужин',
      description:
          'Праздничное меню из зелени степи и ранних овощей. Фотоотчёт доступен ниже.',
      startsAt: t0.subtract(const Duration(days: 12, hours: 4)),
      format: EventAccessFormat.open,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[1],
      priceFromRub: 12000,
      isPast: true,
      hasPhotoReport: true,
    ),
    PiligrimEvent(
      id: 'p2',
      title: 'Дегустация вин Кавказа',
      description:
          'Пять позиций и закуски от кухни. Событие завершено.',
      startsAt: t0.subtract(const Duration(days: 45, hours: 2)),
      format: EventAccessFormat.closed,
      coverAssetPath: PiligrimInteriorAssets.allInteriorPngs[2],
      priceFromRub: null,
      isPast: true,
      hasPhotoReport: true,
    ),
  ];
}

List<PiligrimEvent> upcomingEventsSorted(List<PiligrimEvent> all) {
  final u = all.where((e) => !e.isPast).toList();
  u.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return u;
}

List<PiligrimEvent> pastEventsSorted(List<PiligrimEvent> all) {
  final p = all.where((e) => e.isPast).toList();
  p.sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return p;
}

List<PiligrimNewsPost> mockNewsPosts() {
  final t0 = _anchorToday();
  return [
    PiligrimNewsPost(
      id: 'n1',
      title: 'Сезонное меню обновлено',
      body:
          'В путь добавили блюда с дымком очага и новые гарниры из зелени. Проводники расскажут историю каждой позиции за столом.',
      publishedAt: t0.subtract(const Duration(days: 2)),
    ),
    PiligrimNewsPost(
      id: 'n2',
      title: 'Винная карта: новый раздел',
      body:
          'Расширили подборку амберных и оранжевых вин — к степным и дымным вкусам кухни.',
      publishedAt: t0.subtract(const Duration(days: 6)),
    ),
    PiligrimNewsPost(
      id: 'n3',
      title: 'Герой кухни',
      body:
          'На две недели к нам присоединился шеф из Алматинской школы — в меню появились лимитированные блюда.',
      publishedAt: t0.subtract(const Duration(days: 18)),
    ),
  ];
}
