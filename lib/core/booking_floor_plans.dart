// Схемы залов ресторана для визуального выбора стола при бронировании.
//
// Данные о свободных/занятых столах всегда приходят живьём с бэкенда
// (GET /bookings/tables/, источник — Remarked CRM) — здесь хранится только
// статическая геометрия: расположение столов на плане и стены с окнами.
// Координаты подобраны вручную по планам залов, переданным администрацией
// (скриншоты из панели Remarked), и являются приближением — цель схемы дать
// герою общее ощущение расположения стола (у окна / в центре / у входа),
// а не точный чертёж.
//
// Реальные зоны в Remarked для этой точки называются «1 Этаж» и «2 Этаж»
// (подтверждено живым запросом, см. backend/docs/remarked.md — «реальный
// стол («33»), зал «1 Этаж»»). Столы 11–44 относятся к «1 Этажу», 201–225 —
// ко «2 Этажу» (см. floorPlanForZone). `roomLabel`/`areaLabel` ниже — это
// подписи конкретных зон на присланных планах («Терраса», «Главный зал»),
// они используются только как декоративный подзаголовок на схеме, не для
// сопоставления с зоной с бэкенда.
//
// Привязка к реальному залу с бэкенда (BookingZone) — по названию зала, а
// при его несовпадении — по фактическим номерам свободных столов
// (см. resolveFloorPlan), т.к. `id`/порядок зала не гарантированы и могут
// отличаться между окружениями (см. backend/docs/bookings.md, раздел «Залы»).
// Если ни один способ не сработал — вызывающий код должен откатиться на
// старый список свободных столов, схема не показывается.
import '../data/models/booking_table.dart';
import '../data/models/booking_zone.dart';

/// `rect` — прямоугольный стол шире, чем выше (столы у входа 41–44).
/// `diamond` — квадрат, повёрнутый на 45° (банкетные столы 21–26).
enum FloorPlanTableShape { round, square, rect, diamond }

/// Одна позиция стола на схеме зала. Координаты — доли (0..1) от размера
/// холста зала, считая от левого верхнего угла зоны, доступной для
/// расстановки (без учёта отступа под стены).
class FloorPlanTable {
  const FloorPlanTable({
    required this.name,
    required this.left,
    required this.top,
    this.shape = FloorPlanTableShape.round,
    this.diameter = 40,
    this.seatAngles = const [0, 180],
  });

  /// Номер стола — должен совпадать с `BookingTable.name`, приходящим
  /// с бэкенда (`GET /bookings/tables/`), чтобы схема могла определить
  /// свободен стол или занят.
  final String name;
  final double left;
  final double top;
  final FloorPlanTableShape shape;

  /// Визуальный диаметр/сторона в логических пикселях при эталонной
  /// ширине холста (масштабируется вместе со схемой).
  final double diameter;

  /// Углы (в градусах, 0 = «вверх», по часовой стрелке), под которыми
  /// вокруг стола рисуются метки-«стулья» — как на плане Remarked.
  final List<double> seatAngles;
}

enum FloorPlanWindowSide { left, right, top, bottom }

class FloorPlanConfig {
  const FloorPlanConfig({
    required this.roomLabel,
    required this.areaLabel,
    required this.aspectRatio,
    required this.referenceWidth,
    required this.minSeatGapPx,
    required this.tables,
    required this.windowSides,
  });

  final String roomLabel;
  final String areaLabel;

  /// Ширина / высота холста зала.
  final double aspectRatio;

  /// Ширина (в px) скриншота-первоисточника, с которого сняты координаты
  /// столов — база для расчёта масштаба схемы на реальном экране
  /// (см. `BookingFloorPlan`: `trueScale`/`visualScale`).
  final double referenceWidth;

  /// Минимальное расстояние (px на `referenceWidth`) между центрами двух
  /// соседних столов этой схемы — используется, чтобы тач-таргет стола
  /// никогда не мог перекрыть тач-таргет соседа, при любом реальном
  /// масштабе. Посчитано вручную по актуальным координатам ниже.
  final double minSeatGapPx;

  final List<FloorPlanTable> tables;
  final Set<FloorPlanWindowSide> windowSides;
}

/// «Терраса» (2 этаж) — 12 круглых столов в три ряда, панорамное
/// остекление по обеим длинным сторонам и по нижней стене. Координаты
/// сняты напрямую со скриншота живого плана Remarked (не черновой набросок).
const terraceFloorPlan = FloorPlanConfig(
  roomLabel: 'Терраса',
  areaLabel: '146,3 м²',
  aspectRatio: 1.84,
  referenceWidth: 748,
  minSeatGapPx: 100,
  windowSides: {FloorPlanWindowSide.left, FloorPlanWindowSide.right, FloorPlanWindowSide.bottom},
  tables: [
    // Круглые столы на террасе реально на 4 гостя, не на 2 — метки-стулья
    // по всем 4 сторонам (было только сверху/снизу, что читалось как
    // 2-местный стол).
    FloorPlanTable(name: '201', left: 0.297, top: 0.180, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '202', left: 0.461, top: 0.180, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '203', left: 0.638, top: 0.180, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '211', left: 0.201, top: 0.441, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '212', left: 0.374, top: 0.441, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '213', left: 0.549, top: 0.441, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '214', left: 0.733, top: 0.441, diameter: 58, seatAngles: [0, 90, 180, 270]),
    // Угловые столы — тот же 4-местный стол, но метки развёрнуты по
    // диагонали (на 45°), как на исходном плане.
    FloorPlanTable(name: '221', left: 0.099, top: 0.687, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '222', left: 0.291, top: 0.687, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '223', left: 0.463, top: 0.687, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '224', left: 0.640, top: 0.687, diameter: 58, seatAngles: [0, 90, 180, 270]),
    FloorPlanTable(name: '225', left: 0.823, top: 0.687, diameter: 58, seatAngles: [45, 135, 225, 315]),
  ],
);

/// «Главный зал» (1 этаж) — 19 столов: пары небольших квадратных столов
/// вдоль левой стены, одиночные вдоль правой, банкетные столы-ромбы в
/// центре, прямоугольные столы в ряд у входа. Остекление — по обеим
/// боковым стенам. Координаты сняты напрямую со скриншота живого плана
/// Remarked.
const mainHallFloorPlan = FloorPlanConfig(
  roomLabel: 'Главный зал',
  areaLabel: '113,4 м²',
  aspectRatio: 1.35,
  referenceWidth: 640,
  minSeatGapPx: 76,
  // На исходном плане красная линия окон идёт по обеим боковым стенам и
  // по нижней (та же картина, что и на террасе).
  windowSides: {FloorPlanWindowSide.left, FloorPlanWindowSide.right, FloorPlanWindowSide.bottom},
  tables: [
    // Левая стена — пары небольших столов на 2 гостей. Раздвинуты
    // относительно скриншота (было 0.089/0.158 — 44px на референсной
    // ширине, вплотную к будущему мин. тач-таргету) — см. minSeatGapPx.
    FloorPlanTable(name: '11', left: 0.065, top: 0.113, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '12', left: 0.185, top: 0.113, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '13', left: 0.065, top: 0.341, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '14', left: 0.185, top: 0.341, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '15', left: 0.065, top: 0.570, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '16', left: 0.185, top: 0.570, shape: FloorPlanTableShape.square, diameter: 48),
    // Центр — банкетные столы-ромбы (4 гостя, стул на каждом углу)
    FloorPlanTable(name: '21', left: 0.431, top: 0.113, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '22', left: 0.619, top: 0.113, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '23', left: 0.431, top: 0.341, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '24', left: 0.619, top: 0.341, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '25', left: 0.431, top: 0.570, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    FloorPlanTable(name: '26', left: 0.619, top: 0.570, shape: FloorPlanTableShape.diamond, diameter: 58, seatAngles: [45, 135, 225, 315]),
    // Правая стена — одиночные столы. Было по одному стулу (только сверху) —
    // с одним тиком выглядело как стол на одного; стол на 2 гостей, второй
    // стул снизу (тот же паттерн top/bottom, что и у пар 11-16).
    FloorPlanTable(name: '31', left: 0.841, top: 0.113, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '32', left: 0.841, top: 0.341, shape: FloorPlanTableShape.square, diameter: 48),
    FloorPlanTable(name: '33', left: 0.841, top: 0.570, shape: FloorPlanTableShape.square, diameter: 48),
    // Ряд у входа — прямоугольные столы, стулья по бокам
    FloorPlanTable(name: '41', left: 0.233, top: 0.893, shape: FloorPlanTableShape.rect, diameter: 54, seatAngles: [90, 270]),
    FloorPlanTable(name: '42', left: 0.400, top: 0.893, shape: FloorPlanTableShape.rect, diameter: 54, seatAngles: [90, 270]),
    FloorPlanTable(name: '43', left: 0.564, top: 0.893, shape: FloorPlanTableShape.rect, diameter: 54, seatAngles: [90, 270]),
    FloorPlanTable(name: '44', left: 0.727, top: 0.893, shape: FloorPlanTableShape.rect, diameter: 54, seatAngles: [90, 270]),
  ],
);

const List<FloorPlanConfig> knownFloorPlans = [terraceFloorPlan, mainHallFloorPlan];

/// Подбирает готовую схему зала по названию, пришедшему с бэкенда
/// (`GET /bookings/zones/`). Основной паттерн — «1 Этаж»/«2 Этаж» (реальные
/// названия зон в Remarked для этой точки, см. комментарий выше файла);
/// «терраса»/«главный зал» оставлены как запасной паттерн на случай, если
/// зону когда-нибудь переименуют в сторону подписи с самого плана.
/// Возвращает `null`, если ни один паттерн не подошёл — не единственный
/// способ определения, см. [resolveFloorPlan].
FloorPlanConfig? floorPlanForZone(BookingZone zone) {
  final name = zone.name.toLowerCase();
  // «1 Этаж» — столы 11–44, план с подписью «Главный зал» на скриншоте.
  if (name.contains('1 этаж') || name.contains('1-й этаж') || name.contains('главн')) {
    return mainHallFloorPlan;
  }
  // «2 Этаж» — столы 201–225, план с подписью «Терраса» на скриншоте.
  if (name.contains('2 этаж') || name.contains('2-й этаж') || name.contains('терас')) {
    return terraceFloorPlan;
  }
  return null;
}

/// Подбирает схему по фактическим номерам свободных столов
/// (`GET /bookings/tables/`) — работает независимо от того, как называется
/// зал в Remarked (`floorPlanForZone` рассчитан на "человеческие" названия
/// вроде "Терраса"/"Главный зал", но точка может быть настроена иначе,
/// например "Зал 1"/"Зал 2", см. backend/docs/bookings.md). Номера столов
/// двух известных схем не пересекаются (`201–225` против `11–44`), поэтому
/// достаточно посчитать, с какой схемой совпадений больше.
FloorPlanConfig? floorPlanForTables(Iterable<BookingTable> tables) {
  final names = tables.map((t) => t.name).whereType<String>().toSet();
  if (names.isEmpty) return null;

  int overlap(FloorPlanConfig config) =>
      config.tables.map((t) => t.name).toSet().intersection(names).length;

  final terraceScore = overlap(terraceFloorPlan);
  final mainHallScore = overlap(mainHallFloorPlan);
  if (terraceScore == 0 && mainHallScore == 0) return null;
  return terraceScore >= mainHallScore ? terraceFloorPlan : mainHallFloorPlan;
}

/// Единая точка входа для экрана бронирования: сперва пробует опознать зал
/// по названию, затем — по фактическим номерам столов. `null` означает, что
/// схему показать нельзя (незнакомый зал/сервер) — вызывающий код должен
/// откатиться на список столов.
FloorPlanConfig? resolveFloorPlan(BookingZone? zone, Iterable<BookingTable> tables) {
  if (zone != null) {
    final byName = floorPlanForZone(zone);
    if (byName != null) return byName;
  }
  return floorPlanForTables(tables);
}
