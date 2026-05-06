// Меню Piligrim — видео-лента (TikTok-стиль).
// Вертикальный скролл блюд + горизонтальный свайп фото + детальная карточка.
// ТЗ: без лайков, комментариев, корзины — только атмосфера и информация.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dish_model.dart';
import 'menu_data.dart';

// ── Цвета Piligrim — официальный брендбук ────────────────────────────────────
const _gold    = Color(0xFF7BA5B8);   // Мөлдір су — стальной синий
const _goldDim = Color(0x8C7BA5B8);   // Мөлдір су dim
const _ember   = Color(0xFFC4956A);   // Сары дала — тёплый акцент
const _white   = Color(0xFFF2EDE4);   // Ақ аспан — кремовый
const _whiteDim= Color(0x73F2EDE4);   // dim cream
const _card    = Color(0xFF2A2826);   // Қара жер — карточки
const _glassB  = Color(0x1AF2EDE4);   // glass border
const _fruit   = Color(0xFF8B1A1A);   // Піскен жеміс — аллерген

// ── Символы категорий ─────────────────────────────────────────────────────────
const _catSymbols = <String, String>{
  'Супы': '◈', 'Холодное': '◇', 'Горячее': '✦',
  'Десерты': '✧', 'Напитки': '◆', 'Вино': '❖',
};

// ═════════════════════════════════════════════════════════════════════════════
// TikTokMenuView — корневой виджет меню
// ═════════════════════════════════════════════════════════════════════════════
class TikTokMenuView extends StatefulWidget {
  const TikTokMenuView({super.key});

  @override
  State<TikTokMenuView> createState() => _TikTokMenuViewState();
}

class _TikTokMenuViewState extends State<TikTokMenuView> {
  late final List<DishItem> _dishes;
  String _cat = 'Все';

  static const _cats = <String>['Все', 'Супы', 'Холодное', 'Горячее', 'Десерты', 'Напитки', 'Вино'];

  @override
  void initState() {
    super.initState();
    _dishes = buildDishItems();
  }

  List<DishItem> get _filtered =>
      _cat == 'Все' ? _dishes : _dishes.where((d) => d.data.category == _cat).toList();

  void _showDetail(DishItem dish) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DishDetailSheet(dish: dish),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Dish pages (vertical PageView) ──────────────────────────────────
        if (filtered.isEmpty)
          const Center(
            child: Text('Нет блюд в этой категории', style: TextStyle(color: _whiteDim)),
          )
        else
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final dish = filtered[i];
              return _DishPage(
                dish: dish,
                onDetail: () => _showDetail(dish),
              );
            },
          ),

        // ── Top overlay: header + category pills ─────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: topPad + 6, bottom: 14, left: 18, right: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xDD0E1311), Color(0x880E1311), Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'МЕНЮ',
                      style: TextStyle(
                        color: _white,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _glassB),
                      ),
                      child: Text(
                        'свайп ↑↓',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 28,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final active = _cats[i] == _cat;
                      return Padding(
                        padding: EdgeInsets.only(right: i < _cats.length - 1 ? 6 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _cat = _cats[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: active
                                  ? _gold.withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.38),
                              border: Border.all(
                                color: active ? _goldDim : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _cats[i].toUpperCase(),
                              style: TextStyle(
                                color: active ? _gold : _whiteDim,
                                fontSize: 9,
                                letterSpacing: 0.8,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DishPage — одна страница блюда (горизонтальный свайп фото + оверлеи)
// ═════════════════════════════════════════════════════════════════════════════
class _DishPage extends StatefulWidget {
  final DishItem dish;
  final VoidCallback onDetail;

  const _DishPage({required this.dish, required this.onDetail});

  @override
  State<_DishPage> createState() => _DishPageState();
}

class _DishPageState extends State<_DishPage> {
  int _photoIdx = 0;

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final photos = dish.photos;
    final sym = _catSymbols[dish.data.category] ?? '✦';
    final botPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Photo layers (horizontal PageView) ────────────────────────────
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _photoIdx = i),
          itemBuilder: (_, i) => _PhotoFrame(photo: photos[i], symbol: sym),
        ),

        // ── Bottom vignette ────────────────────────────────────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xAA000000),
                  Color(0xF0000000),
                ],
                stops: [0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
        ),

        // ── Photo dots + dish info ──────────────────────────────────────────
        Positioned(
          bottom: botPad + 100,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Horizontal photo dots
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10),
                child: Row(
                  children: [
                    ...List.generate(
                      photos.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _photoIdx == i ? 20 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: _photoIdx == i ? _gold : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${photos.length} фото  →',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Dish info — tap opens detail sheet
              GestureDetector(
                onTap: widget.onDetail,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DishInfoOverlay(data: dish.data),
                ),
              ),
            ],
          ),
        ),

        // ── "Подробнее" button (bottom right) ─────────────────────────────
        Positioned(
          right: 16,
          bottom: botPad + 110,
          child: GestureDetector(
            onTap: widget.onDetail,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(color: _gold.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('◈', style: TextStyle(fontSize: 20, color: _gold, height: 1.0)),
                  const SizedBox(height: 4),
                  Text(
                    'Состав',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9,
                      letterSpacing: 0.3,
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

// ═════════════════════════════════════════════════════════════════════════════
// _PhotoFrame — атмосферный градиент-фон блюда
// ═════════════════════════════════════════════════════════════════════════════
class _PhotoFrame extends StatelessWidget {
  final DishPhoto photo;
  final String symbol;

  const _PhotoFrame({required this.photo, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [photo.top, photo.mid, photo.bot],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: photo.glowCenter,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    photo.glow.withValues(alpha: 0.28),
                    photo.glow.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment(-photo.glowCenter.x, -photo.glowCenter.y),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [photo.glow.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 180,
              color: Colors.white.withValues(alpha: 0.025),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DishInfoOverlay — информация о блюде внизу страницы
// ═════════════════════════════════════════════════════════════════════════════
class _DishInfoOverlay extends StatelessWidget {
  final MockMenuDish data;

  const _DishInfoOverlay({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            '${_catSymbols[data.category] ?? '✦'}  ${data.category.toUpperCase()}',
            style: const TextStyle(color: _gold, fontSize: 9, letterSpacing: 1.3),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w500,
            height: 1.15,
            shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              data.priceLabel,
              style: const TextStyle(
                color: _gold,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              data.weight,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          data.description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            height: 1.45,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (data.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: data.tags.map((tag) => _DietTagChip(tag: tag)).toList(),
          ),
        ],
        const SizedBox(height: 6),
        // Hint to tap for details
        Row(
          children: [
            Text('◌', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35), height: 1.0)),
            const SizedBox(width: 4),
            Text(
              'нажмите для состава и истории',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Чип диетического тега ─────────────────────────────────────────────────────
class _DietTagChip extends StatelessWidget {
  final DishTag tag;
  const _DietTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: tag.isAllergen
            ? _fruit.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: tag.isAllergen
              ? _fruit.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        tag.label,
        style: TextStyle(
          color: tag.isAllergen
              ? const Color(0xFFD07070)
              : Colors.white.withValues(alpha: 0.65),
          fontSize: 9.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DishDetailSheet — полная карточка блюда (состав, вес, история)
// ТЗ: "Свайп вправо — открывается полная карточка блюда: расширенное описание,
//      состав, аллергены, вес, история блюда (если есть)"
// ═════════════════════════════════════════════════════════════════════════════
class _DishDetailSheet extends StatelessWidget {
  final DishItem dish;
  const _DishDetailSheet({required this.dish});

  @override
  Widget build(BuildContext context) {
    final d = dish.data;
    final botPad = MediaQuery.of(context).padding.bottom;
    final sym = _catSymbols[d.category] ?? '✦';
    final photo = dish.photos.first;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: _glassB)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 0),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Hero header with gradient
            Container(
              height: 160,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [photo.top, photo.mid, photo.bot],
                ),
                boxShadow: [
                  BoxShadow(
                    color: photo.glow.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Glow
                  Align(
                    alignment: photo.glowCenter,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            photo.glow.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Symbol watermark
                  Center(
                    child: Text(
                      sym,
                      style: TextStyle(
                        fontSize: 100,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Category badge
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$sym  ${d.category.toUpperCase()}',
                        style: const TextStyle(color: _gold, fontSize: 9, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  // Price + weight
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.priceLabel,
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                        Text(
                          d.weight,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(20, 18, 20, botPad + 24),
                children: [
                  // Name
                  Text(
                    d.name,
                    style: GoogleFonts.outfit(
                      color: _white,
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tags
                  if (d.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: d.tags.map((t) => _DietTagChip(tag: t)).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Divider
                  Container(height: 0.5, color: _glassB),
                  const SizedBox(height: 14),
                  // Description
                  _DetailSection(
                    symbol: '◈',
                    title: 'Описание',
                    content: d.description,
                  ),
                  const SizedBox(height: 16),
                  // Ingredients
                  _DetailSection(
                    symbol: '✦',
                    title: 'Состав',
                    content: d.ingredients,
                  ),
                  const SizedBox(height: 16),
                  // Story (if any)
                  if (d.story != null) ...[
                    _DetailSection(
                      symbol: '☽',
                      title: 'История блюда',
                      content: d.story!,
                      accentColor: _ember,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Allergens note
                  if (d.tags.any((t) => t.isAllergen)) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _fruit.withValues(alpha: 0.08),
                        border: Border.all(color: _fruit.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('◈', style: TextStyle(fontSize: 16, color: _fruit.withValues(alpha: 0.8), height: 1.0)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Содержит аллергены: ${d.tags.where((t) => t.isAllergen).map((t) => t.label).join(', ')}',
                              style: TextStyle(
                                color: _fruit.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Секция детали блюда (иконка + заголовок + текст)
class _DetailSection extends StatelessWidget {
  final String symbol;
  final String title;
  final String content;
  final Color accentColor;

  const _DetailSection({
    required this.symbol,
    required this.title,
    required this.content,
    this.accentColor = _gold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(symbol, style: TextStyle(fontSize: 14, color: accentColor.withValues(alpha: 0.8), height: 1.0)),
            const SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.8),
                fontSize: 9.5,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          content,
          style: TextStyle(
            color: _white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
