// Мок-данные афиши и новостей — ТЗ раздел «Афиша и новости»
// Цвета/тон: piligrim_design_spec.md (герой, без эмодзи)
import 'package:flutter/foundation.dart';

import '../core/interior_assets.dart';
import '../core/media_url.dart';
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
      imageUrl: resolveMediaUrl(parseStringOrNull(json['image'] ?? json['image_url'])),
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
  final covers = PiligrimInteriorAssets.allInteriorPngs;
  return [
    // ── Ближайшие (афиша) ──
    PiligrimEvent(
      id: '101',
      title: 'Вечер живой кобыза',
      description:
          'Импровизация на степных мотивах и дегустация блюд из печи. Пространство «АУА» — ивент-спейс Piligrim. Запись — заявка: ресторан перезвонит для подтверждения.',
      startsAt: t0.add(const Duration(days: 2, hours: 19)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[0],
      priceFromRub: null,
    ),
    PiligrimEvent(
      id: '102',
      title: 'Закрытый ужин с шефом',
      description:
          'Сезонное меню путешествия по Центральной Азии, вино и рассказ проводника о традициях. Закрытый формат — список гостей согласуется заранее.',
      startsAt: t0.add(const Duration(days: 6, hours: 19, minutes: 30)),
      format: EventAccessFormat.closed,
      coverAssetPath: covers[1],
      priceFromRub: 18500,
    ),
    PiligrimEvent(
      id: '103',
      title: 'Мастер-класс: тесто и очаг',
      description:
          'Работа с тестом в духе кочевой кухни, выпечка на открытом огне. Подходит героям с любым опытом — проводник ведёт шаг за шагом.',
      startsAt: t0.add(const Duration(days: 10, hours: 16)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[2],
      priceFromRub: 4500,
    ),
    PiligrimEvent(
      id: '104',
      title: 'Дегустация степных трав',
      description:
          'Пять настоев и закусок к дымным блюдам кухни. Короткий ритуал знакомства с меню сезона — без спешки, за общим столом.',
      startsAt: t0.add(const Duration(days: 13, hours: 18)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[0],
      priceFromRub: 6500,
    ),
    PiligrimEvent(
      id: '105',
      title: 'Ночь длинных столов',
      description:
          'Совместный стол на террасе: свечи, меню на выбор проводника, живая музыка в полутоне. Тёплый вечер без дедлайна.',
      startsAt: t0.add(const Duration(days: 18, hours: 20)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[1],
      priceFromRub: null,
    ),
    PiligrimEvent(
      id: '106',
      title: 'Джаз у очага',
      description:
          'Квартет, авторские закуски и коктейли с дымком саксаула. Открытый формат — можно прийти парой или небольшой компанией.',
      startsAt: t0.add(const Duration(days: 24, hours: 21)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[2],
      priceFromRub: 9000,
    ),
    // ── Архив (прошедшие + фотоотчёты) ──
    PiligrimEvent(
      id: '201',
      title: 'Весеннее равноденствие — ужин',
      description:
          'Праздничное меню из зелени степи и ранних овощей. Вечер завершён — ниже доступен фотоотчёт.',
      startsAt: t0.subtract(const Duration(days: 9, hours: 4)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[1],
      priceFromRub: 12000,
      isPast: true,
      hasPhotoReport: true,
    ),
    PiligrimEvent(
      id: '202',
      title: 'Путь первого огня',
      description:
          'Ритуал зажжения очага и ужин из блюд, приготовленных на углях. Архивный вечер с фотоотчётом для тех, кто не успел на пути.',
      startsAt: t0.subtract(const Duration(days: 22, hours: 3)),
      format: EventAccessFormat.open,
      coverAssetPath: covers[2],
      priceFromRub: 9800,
      isPast: true,
      hasPhotoReport: true,
    ),
    PiligrimEvent(
      id: '203',
      title: 'Закрытый вечер сомелье',
      description:
          'Шесть позиций винной карты и pairing от кухни. Закрытый формат — событие в архиве, фотоотчёт сохранён.',
      startsAt: t0.subtract(const Duration(days: 38, hours: 2)),
      format: EventAccessFormat.closed,
      coverAssetPath: covers[0],
      priceFromRub: 15000,
      isPast: true,
      hasPhotoReport: true,
    ),
    PiligrimEvent(
      id: '204',
      title: 'Дегустация вин Кавказа',
      description:
          'Пять позиций и закуски от кухни. Событие завершено — в карточке доступен фотоотчёт вечера.',
      startsAt: t0.subtract(const Duration(days: 52, hours: 2)),
      format: EventAccessFormat.closed,
      coverAssetPath: covers[1],
      priceFromRub: null,
      isPast: true,
      hasPhotoReport: true,
    ),
    PiligrimEvent(
      id: '205',
      title: 'Банкет «Длинная нить»',
      description:
          'Корпоративный ужин в главном зале: общий стол, живая подача, финальный десерт у очага. Архив без онлайн-продажи — только память пути.',
      startsAt: t0.subtract(const Duration(days: 74, hours: 5)),
      format: EventAccessFormat.closed,
      coverAssetPath: covers[2],
      priceFromRub: null,
      isPast: true,
      hasPhotoReport: false,
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
  final covers = PiligrimInteriorAssets.allInteriorPngs;
  return [
    PiligrimNewsPost(
      id: '301',
      title: 'Сезонное меню обновлено',
      body:
          'В путь добавили блюда с дымком очага и гарниры из ранней зелени. Проводники расскажут историю каждой позиции — без спешки, за столом.',
      publishedAt: t0.subtract(const Duration(days: 1)),
      imageUrl: covers[0],
    ),
    PiligrimNewsPost(
      id: '302',
      title: 'Винная карта: новый раздел',
      body:
          'Расширили подборку амберных и оранжевых вин. Подобрали пары к степным и дымным вкусам кухни — спросите проводника за ужином.',
      publishedAt: t0.subtract(const Duration(days: 4)),
      imageUrl: covers[1],
    ),
    PiligrimNewsPost(
      id: '303',
      title: 'Герой кухни на две недели',
      body:
          'К нам присоединился шеф из Алматинской школы. В меню — лимитированные блюда; количество порций ограничено.',
      publishedAt: t0.subtract(const Duration(days: 9)),
      imageUrl: covers[2],
    ),
    PiligrimNewsPost(
      id: '304',
      title: 'Пространство «АУА» для частных вечеров',
      body:
          'Ивент-спейс принимает закрытые ужины и камерные концерты. Оставьте заявку — менеджер свяжется и предложит сценарий вечера.',
      publishedAt: t0.subtract(const Duration(days: 14)),
      imageUrl: covers[0],
    ),
    PiligrimNewsPost(
      id: '305',
      title: 'Часы работы в праздничные дни',
      body:
          'Режим обновлён: вечерние слоты бронирования расширены, дневной зал открыт с 12:00. Актуальное расписание — на главной и в профиле.',
      publishedAt: t0.subtract(const Duration(days: 21)),
    ),
    PiligrimNewsPost(
      id: '306',
      title: 'Welcome-ритуал у входа',
      body:
          'Новый тёплый напиток при встрече — лёгкий, безалкогольный, с нотами степных трав. Первый глоток пути, пока готовится ваш стол.',
      publishedAt: t0.subtract(const Duration(days: 28)),
      imageUrl: covers[1],
    ),
  ];
}

/// Локальные кадры фотоотчёта для демо-событий (когда API недоступен).
List<String> mockPhotoReportAssetUrls(int eventId) {
  final past = buildMockEvents().where((e) => e.isPast && e.hasPhotoReport);
  final match = past.where((e) => int.tryParse(e.id) == eventId);
  if (match.isEmpty) return const [];
  final cover = match.first.coverAssetPath;
  return [
    cover,
    ...PiligrimInteriorAssets.galleryExtrasExcluding(cover),
  ];
}
