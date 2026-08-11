// Визуальная схема зала для выбора стола при бронировании — замена плоского
// списка «Стол N (до K гостей)» на карту с реальным расположением столов,
// формой (круг/квадрат/прямоугольник/ромб) и метками-«стульями», как в
// живом плане Remarked. Цвет столов — «занят/свободен/выбран». См.
// lib/core/booking_floor_plans.dart за координатами и docs/flutter/booking.md
// за контекстом фичи.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/booking_floor_plans.dart';
import '../core/theme.dart';
import '../data/models/booking_table.dart';
import 'piligrim_tap.dart';

enum _TableStatus { free, selected, occupied, loading }

class _StatusPalette {
  const _StatusPalette({required this.fill, required this.border, required this.text});
  final Color fill;
  final Color border;
  final Color text;
}

_StatusPalette _paletteFor(_TableStatus status) {
  switch (status) {
    case _TableStatus.free:
      // success — тот же зелёный, что и статус «завершено» в истории броней;
      // визуально ближе к живому плану Remarked, чем нейтральный акцент.
      return _StatusPalette(
        fill: PiligrimColors.success.withValues(alpha: 0.18),
        border: PiligrimColors.success.withValues(alpha: 0.85),
        text: PiligrimColors.success,
      );
    case _TableStatus.selected:
      return const _StatusPalette(
        fill: PiligrimColors.steppe,
        border: PiligrimColors.steppe,
        text: PiligrimColors.earthDeep,
      );
    case _TableStatus.occupied:
      return _StatusPalette(
        fill: PiligrimColors.fruit.withValues(alpha: 0.16),
        border: PiligrimColors.fruit.withValues(alpha: 0.55),
        text: PiligrimColors.fruit.withValues(alpha: 0.80),
      );
    case _TableStatus.loading:
      return _StatusPalette(
        fill: PiligrimColors.sky.withValues(alpha: 0.06),
        border: PiligrimColors.sky.withValues(alpha: 0.16),
        text: PiligrimColors.sky.withValues(alpha: 0.30),
      );
  }
}

String _statusSuffix(_TableStatus status) {
  switch (status) {
    case _TableStatus.free:
      return ', свободен';
    case _TableStatus.selected:
      return ', выбран';
    case _TableStatus.occupied:
      return ', занят';
    case _TableStatus.loading:
      return '';
  }
}

class BookingFloorPlan extends StatelessWidget {
  const BookingFloorPlan({
    super.key,
    required this.config,
    required this.zoneName,
    required this.freeTables,
    required this.selectedTable,
    required this.onSelect,
    this.isLoading = false,
  });

  final FloorPlanConfig config;

  /// Название зала, как оно реально называется в Remarked
  /// (`BookingZone.name`, например «1 Этаж») — показывается заголовком
  /// схемы вместо статичной подписи с плана, чтобы не путать героя, если
  /// названия когда-нибудь разойдутся.
  final String zoneName;

  /// Столы, свободные на выбранные дату/время/кол-во гостей
  /// (`BookingProvider.tables`). Стол, отсутствующий в этом списке, но
  /// присутствующий на схеме, считается занятым.
  final List<BookingTable> freeTables;
  final BookingTable? selectedTable;
  final ValueChanged<BookingTable?> onSelect;

  /// Пока идёт запрос `GET /bookings/tables/` — показываем схему в
  /// нейтральном виде вместо угадывания статусов по устаревшим данным.
  final bool isLoading;

  BookingTable? _freeTableByName(String name) {
    for (final t in freeTables) {
      if (t.name == name) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      // Родитель теперь — SingleChildScrollView (unbounded height), без
      // min здесь Column попытался бы стать бесконечно высоким.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          zoneName.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: PiligrimTextStyles.sectionLabel.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.60),
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        // Рамка размером ровно под план (не растягивается на доступную
        // высоту) — реальные пропорции комнаты (aspectRatio) при известной
        // ширине однозначно определяют высоту, тянуть тут больше нечего;
        // родитель (booking_screen.dart) теперь тоже размером под контент,
        // а не искусственно растянут — так рамка со схемой и видимая
        // шторка совпадают, без пустого «мёртвого» пространства вокруг.
        Center(
          child: ConstrainedBox(
            // Планшеты/широкие экраны — план не растягивается по ширине
            // сверх разумного.
            constraints: const BoxConstraints(maxWidth: 460),
            child: ClipRRect(
              borderRadius: PiligrimRadius.mdAll,
              child: Container(
                decoration: BoxDecoration(
                  color: PiligrimColors.earthDeep,
                  borderRadius: PiligrimRadius.mdAll,
                  border: Border.all(color: PiligrimColors.divider),
                ),
                padding: const EdgeInsets.all(10),
                child: AspectRatio(
                  aspectRatio: config.aspectRatio,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 3.2,
                    // Запас под панорамирование при зуме — не настолько
                    // большой, чтобы план мог целиком уехать в пустоту при
                    // обычном (незумленном) перетаскивании.
                    boundaryMargin: const EdgeInsets.all(60),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        // trueScale — реальное отношение холста к
                        // эталонному скриншоту, используется там, где
                        // нельзя ошибиться (тач-таргеты не должны
                        // пересекаться).
                        final trueScale = w / config.referenceWidth;
                        // visualScale — то же самое, но не даёт столам
                        // стать нечитаемо мелкими на узких экранах и не
                        // мешает им вырасти чуть крупнее эталона, если
                        // места достаточно (верхний предел — тоже разумный
                        // потолок, чтобы не раздувались бесконечно).
                        final visualScale = trueScale.clamp(0.65, 1.4);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final side in config.windowSides) _WindowEdge(side: side),
                            for (final t in config.tables)
                              ..._tableWidgets(t, w, h, trueScale, visualScale, config.minSeatGapPx),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: PiligrimColors.divider)),
          ),
          child: _Legend(hasWindows: config.windowSides.isNotEmpty),
        ),
      ],
    );
  }

  List<Widget> _tableWidgets(
    FloorPlanTable t,
    double w,
    double h,
    double trueScale,
    double visualScale,
    double minSeatGapPx,
  ) {
    final free = _freeTableByName(t.name);
    final isSelected = selectedTable != null && selectedTable!.name == t.name;
    final status = isLoading
        ? _TableStatus.loading
        : isSelected
            ? _TableStatus.selected
            : (free != null ? _TableStatus.free : _TableStatus.occupied);
    final palette = _paletteFor(status);

    final cx = t.left * w;
    final cy = t.top * h;
    final visualSize = t.diameter * visualScale;
    // Стулья на ромбе «упираются» в его углы (диагональ квадрата длиннее
    // стороны) — увеличиваем радиус расстановки для этой формы, иначе
    // метки прячутся под скруглённым корпусом стола.
    final seatRadius = t.shape == FloorPlanTableShape.diamond ? visualSize * 0.71 : visualSize / 2;

    // Тач-таргет должен как минимум покрывать видимую фигуру (плюс запас
    // на палец) — раньше он мог быть даже МЕНЬШЕ стола, что визуально
    // выглядит нормально, но тапать неудобно. Верхняя граница — реальное
    // (не «подрощенное» для читаемости) расстояние до соседнего стола,
    // чтобы хитбоксы двух столов никогда не могли перекрыться.
    final safeGap = math.max(28.0, minSeatGapPx * trueScale - 4);
    final hitSize = math.min(visualSize + 10, safeGap);

    final tappable = status == _TableStatus.free || status == _TableStatus.selected;

    return [
      for (final angle in t.seatAngles)
        _SeatTick(
          cx: cx,
          cy: cy,
          angleDeg: angle,
          radius: seatRadius,
          color: palette.border,
          scale: visualScale,
        ),
      Positioned(
        left: cx - hitSize / 2,
        top: cy - hitSize / 2,
        width: hitSize,
        height: hitSize,
        child: _TableTapTarget(
          label: t.name,
          shape: t.shape,
          visualSize: visualSize,
          palette: palette,
          isSelected: status == _TableStatus.selected,
          statusSuffix: _statusSuffix(status),
          fontScale: visualScale,
          onTap: tappable ? () => onSelect(isSelected ? null : free) : null,
        ),
      ),
    ];
  }
}

// Тап-зона стола: обёртка фиксированного (≥28, до 44) размера вокруг
// визуально меньшей фигуры стола — увеличивает область тапа, не трогая
// внешний вид. При тапе сперва коротко подтверждает выбор (подсветка +
// галочка ~200мс), затем вызывает реальный колбэк выбора — так герой видит
//, что нажатие точно засчиталось, до того как шторка бронирования закроется.
class _TableTapTarget extends StatefulWidget {
  const _TableTapTarget({
    required this.label,
    required this.shape,
    required this.visualSize,
    required this.palette,
    required this.isSelected,
    required this.statusSuffix,
    required this.fontScale,
    required this.onTap,
  });

  final String label;
  final FloorPlanTableShape shape;
  final double visualSize;
  final _StatusPalette palette;
  final bool isSelected;
  final String statusSuffix;
  final double fontScale;
  final VoidCallback? onTap;

  @override
  State<_TableTapTarget> createState() => _TableTapTargetState();
}

class _TableTapTargetState extends State<_TableTapTarget> {
  bool _confirming = false;

  Future<void> _handleTap() async {
    final onTap = widget.onTap;
    if (onTap == null || _confirming) return;
    setState(() => _confirming = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final showConfirmed = widget.isSelected || _confirming;
    final palette = _confirming ? _paletteFor(_TableStatus.selected) : widget.palette;

    return Semantics(
      button: widget.onTap != null,
      selected: showConfirmed,
      label: 'Стол ${widget.label}${widget.statusSuffix}',
      excludeSemantics: true,
      child: PiligrimTap(
        onTap: widget.onTap == null ? null : _handleTap,
        borderRadius: widget.shape == FloorPlanTableShape.round
            ? BorderRadius.circular(999)
            : BorderRadius.circular(4),
        child: Center(
          child: SizedBox(
            width: widget.visualSize,
            height: widget.visualSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              // fit: expand — без него у Stack'а с непозиционированными
              // детьми свободные (loose) констрейнты, и _TableVisual
              // сжимается до размера текста номера, а не до полного
              // visualSize. Ровно это и было причиной «оторванных» от
              // стола стульев: сам стол рисовался маленьким, а метки-стулья
              // расставлялись по честному (большому) радиусу.
              fit: StackFit.expand,
              children: [
                _TableVisual(
                  label: widget.label,
                  shape: widget.shape,
                  palette: palette,
                  isSelected: showConfirmed,
                  fontScale: widget.fontScale,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: AnimatedScale(
                    scale: showConfirmed ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: ExcludeSemantics(
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: PiligrimColors.steppe,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '✓',
                          style: TextStyle(
                            color: PiligrimColors.earthDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Чистая отрисовка корпуса стола (форма + номер), без тапа и без хитбокса —
// используется внутри _TableTapTarget.
class _TableVisual extends StatelessWidget {
  const _TableVisual({
    required this.label,
    required this.shape,
    required this.palette,
    required this.isSelected,
    required this.fontScale,
  });

  final String label;
  final FloorPlanTableShape shape;
  final _StatusPalette palette;
  final bool isSelected;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final isRound = shape == FloorPlanTableShape.round;
    // Заметно более острые углы, чем раньше (было 8-10) — в референсе из
    // CRM квадраты и ромбы выглядят почти без скругления, а не как
    // «таблетки», которые на маленьком размере читаются как круги.
    final borderRadius = switch (shape) {
      FloorPlanTableShape.round => BorderRadius.circular(999),
      FloorPlanTableShape.rect => BorderRadius.circular(4),
      FloorPlanTableShape.square || FloorPlanTableShape.diamond => BorderRadius.circular(3),
    };

    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: palette.fill,
        shape: isRound ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isRound ? null : borderRadius,
        border: Border.all(color: palette.border, width: isSelected ? 0 : 1.4),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: PiligrimColors.steppe.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );

    // Ромб — квадрат, повёрнутый на 45°; подпись рисуется отдельным слоем
    // сверху, чтобы номер стола оставался читаемым и не крутился вместе с
    // корпусом стола.
    if (shape == FloorPlanTableShape.diamond) {
      box = Transform.rotate(angle: math.pi / 4, child: box);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: box),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: PiligrimTextStyles.micro.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
                fontSize: 11.5 * fontScale,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Метка-«стул» рядом со столом — короткий скруглённый штрих, развёрнутый
// вдоль радиуса от центра стола (angleDeg: 0 = вверх, по часовой стрелке).
class _SeatTick extends StatelessWidget {
  const _SeatTick({
    required this.cx,
    required this.cy,
    required this.angleDeg,
    required this.radius,
    required this.color,
    required this.scale,
  });

  final double cx;
  final double cy;
  final double angleDeg;
  final double radius;
  final Color color;
  final double scale;

  static const double _baseWidth = 15;
  static const double _baseHeight = 7;

  @override
  Widget build(BuildContext context) {
    final width = _baseWidth * scale;
    final height = _baseHeight * scale;
    final rad = angleDeg * math.pi / 180;
    // Зазор до края стола сведён почти к нулю — стул должен «прилипать»
    // к столу, как на референсе из CRM, а не висеть отдельно.
    final dist = radius + height / 2 - 1.5;
    final dx = math.sin(rad) * dist;
    final dy = -math.cos(rad) * dist;

    return Positioned(
      left: cx + dx - width / 2,
      top: cy + dy - height / 2,
      width: width,
      height: height,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Transform.rotate(
            angle: rad,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Тонкая светящаяся полоса вдоль стены с окнами — используем water
// («Мөлдір су», прозрачная вода) как визуальную метафору стекла, а не
// буквальный красный, который в этой же схеме уже означает «стол занят».
// Рисуется строго внутри холста (без отрицательных отступов): InteractiveViewer
// по умолчанию клипует свой child по границам вьюпорта, поэтому полоса,
// «вытекающая» наружу через отрицательный Positioned, была бы не видна.
class _WindowEdge extends StatelessWidget {
  const _WindowEdge({required this.side});

  final FloorPlanWindowSide side;

  @override
  Widget build(BuildContext context) {
    final vertical = side == FloorPlanWindowSide.left || side == FloorPlanWindowSide.right;
    final gradient = LinearGradient(
      begin: switch (side) {
        FloorPlanWindowSide.left => Alignment.centerLeft,
        FloorPlanWindowSide.right => Alignment.centerRight,
        FloorPlanWindowSide.top => Alignment.topCenter,
        FloorPlanWindowSide.bottom => Alignment.bottomCenter,
      },
      end: Alignment.center,
      colors: [
        PiligrimColors.water.withValues(alpha: 0.55),
        PiligrimColors.water.withValues(alpha: 0.0),
      ],
    );

    return Positioned(
      left: side == FloorPlanWindowSide.right ? null : 0,
      right: side == FloorPlanWindowSide.left ? null : 0,
      top: side == FloorPlanWindowSide.bottom ? null : 0,
      bottom: side == FloorPlanWindowSide.top ? null : 0,
      width: vertical ? 8 : null,
      height: vertical ? null : 8,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasWindows});

  final bool hasWindows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        const _LegendItem(color: PiligrimColors.success, label: 'Свободен'),
        const _LegendItem(color: PiligrimColors.steppe, label: 'Выбран'),
        const _LegendItem(color: PiligrimColors.fruit, label: 'Занят'),
        if (hasWindows) const _LegendItem(color: PiligrimColors.water, label: 'Окна', isBar: true),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.isBar = false});

  final Color color;
  final String label;
  final bool isBar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isBar
            ? Container(
                width: 14,
                height: 9,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: 6),
        Text(
          label,
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.60),
          ),
        ),
      ],
    );
  }
}
