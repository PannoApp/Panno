// Экран Меню — «Основной путь»
// Режим 1: Видео-лента (Reels-style PageView)
// Режим 2: Классическое меню с поиском и фильтрами
// Состояние режима сохраняется через SharedPreferences
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/menu_data.dart';
import '../widgets/dish_elements.dart';
import '../widgets/dish_video_card.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_info_section.dart';
import '../widgets/piligrim_tap.dart';

enum MenuMode { feed, classic }

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  MenuMode _mode = MenuMode.feed;
  bool _loaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('menu_mode');
    if (mounted) {
      setState(() {
        _mode = saved == 'classic' ? MenuMode.classic : MenuMode.feed;
        _loaded = true;
      });
    }
  }

  Future<void> _setMode(MenuMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu_mode', mode == MenuMode.classic ? 'classic' : 'feed');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_loaded) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        children: [
          const Positioned.fill(
            child: PiligrimBackground(
              textureOpacity: 0.45,
              vignetteIntensity: 0.25,
            ),
          ),

          // Контент режима
          AnimatedSwitcher(
            duration: 400.ms,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: _mode == MenuMode.feed
                ? const _VideoFeedSection(key: ValueKey('feed'))
                : const _ClassicMenuSection(key: ValueKey('classic')),
          ),

          // Header (поверх контента)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MenuHeader(
              mode: _mode,
              onModeChanged: _setMode,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — переключатель режимов
// ─────────────────────────────────────────────────────────────────────────────
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.mode, required this.onModeChanged});
  final MenuMode mode;
  final ValueChanged<MenuMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PiligrimColors.earthDeep.withValues(alpha: 0.95),
              PiligrimColors.earthDeep.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Row(
            children: [
              // Логотип / заголовок секции
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'assets/images/bird_totem (1).svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.steppe.withValues(alpha: 0.6),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'МЕНЮ',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.water.withValues(alpha: 0.6),
                      letterSpacing: 3.0,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Переключатель «Путь» / «Свиток»
              _ModeSwitcher(mode: mode, onChanged: onModeChanged),
            ],
          ),
        ),
    );
  }
}

// Переключатель режимов меню: кнопки «Путь» (видео) и «Свиток» (классика)
class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});
  final MenuMode mode;
  final ValueChanged<MenuMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: PiligrimColors.earth.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PiligrimColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
            label: 'Путь',
            icon: 'assets/images/bird_totem (1).svg',
            active: mode == MenuMode.feed,
            onTap: () => onChanged(MenuMode.feed),
            radius: const BorderRadius.horizontal(left: Radius.circular(9)),
          ),
          _ModeTab(
            label: 'Свиток',
            icon: 'assets/images/spiral.svg',
            active: mode == MenuMode.classic,
            onTap: () => onChanged(MenuMode.classic),
            radius: const BorderRadius.horizontal(right: Radius.circular(9)),
          ),
        ],
      ),
    );
  }
}

// Одна вкладка переключателя режима (иконка + текст)
class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.radius,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: 220.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? PiligrimColors.water.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: radius,
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              icon,
              width: 13,
              height: 13,
              colorFilter: ColorFilter.mode(
                active ? PiligrimColors.water : PiligrimColors.sky.withValues(alpha: 0.3),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                color: active
                    ? PiligrimColors.water
                    : PiligrimColors.sky.withValues(alpha: 0.35),
                fontWeight: active ? FontWeight.w700 : FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// РЕЖИМ 1: ВИДЕО-ЛЕНТА
// ─────────────────────────────────────────────────────────────────────────────
class _VideoFeedSection extends StatefulWidget {
  const _VideoFeedSection({super.key});

  @override
  State<_VideoFeedSection> createState() => _VideoFeedSectionState();
}

class _VideoFeedSectionState extends State<_VideoFeedSection> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemCount: kDishes.length,
          itemBuilder: (_, i) => DishVideoCard(
            dish: kDishes[i],
            isActive: i == _currentPage,
            onSwipeRight: null, // handled inside card
          ),
        ),

        // Вертикальный прогресс-индикатор справа
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _VerticalProgressDots(
              count: kDishes.length,
              current: _currentPage,
            ),
          ),
        ),
      ],
    );
  }
}

// Точки прокрутки сбоку — показывают, на каком блюде сейчас находится гость
class _VerticalProgressDots extends StatelessWidget {
  const _VerticalProgressDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: 200.ms,
          margin: const EdgeInsets.symmetric(vertical: 2),
          width: 3,
          height: active ? 18 : 5,
          decoration: BoxDecoration(
            color: active
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// РЕЖИМ 2: КЛАССИЧЕСКОЕ МЕНЮ
// ─────────────────────────────────────────────────────────────────────────────
class _ClassicMenuSection extends StatefulWidget {
  const _ClassicMenuSection({super.key});

  @override
  State<_ClassicMenuSection> createState() => _ClassicMenuSectionState();
}

class _ClassicMenuSectionState extends State<_ClassicMenuSection> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final Set<DishTag> _activeFilters = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Dish> get _filteredDishes {
    var dishes = dishesByCategory(_selectedCategory);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      dishes = dishes
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.description.toLowerCase().contains(q))
          .toList();
    }

    if (_activeFilters.isNotEmpty) {
      dishes = dishes
          .where((d) => _activeFilters.every((f) => d.tags.contains(f)))
          .toList();
    }

    return dishes;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final dishes = _filteredDishes;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Верхний отступ под header
        SliverToBoxAdapter(child: SizedBox(height: top + 70)),

        // Поиск
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _SearchBar(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),

        // Категории
        SliverToBoxAdapter(
          child: _CategoryTabs(
            selected: _selectedCategory,
            onSelect: (id) => setState(() => _selectedCategory = id),
          ),
        ),

        // Фильтры
        SliverToBoxAdapter(
          child: _FilterChips(
            active: _activeFilters,
            onToggle: (tag) => setState(() {
              if (_activeFilters.contains(tag)) {
                _activeFilters.remove(tag);
              } else {
                _activeFilters.add(tag);
              }
            }),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Список блюд
        if (dishes.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/spiral.svg',
                    width: 40,
                    height: 40,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.sky.withValues(alpha: 0.12),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Блюда не найдены',
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassicDishCard(
                    dish: dishes[i],
                    animationDelay: Duration(milliseconds: i * 50),
                  ),
                ),
                childCount: dishes.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Поисковая строка
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PiligrimColors.divider),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SvgPicture.asset(
            'assets/images/luk.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              PiligrimColors.sky.withValues(alpha: 0.3),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 14,
                color: PiligrimColors.sky,
              ),
              decoration: InputDecoration(
                hintText: 'Найти блюдо...',
                hintStyle: PiligrimTextStyles.body.copyWith(
                  fontSize: 14,
                  color: PiligrimColors.sky.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              cursorColor: PiligrimColors.water,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Категории (горизонтальный скролл)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kDishCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = kDishCategories[i];
          final active = cat.id == selected;
          return PiligrimTap(
            onTap: () => onSelect(cat.id),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active
                    ? cat.accentColor.withValues(alpha: 0.18)
                    : PiligrimColors.earthDeep,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? cat.accentColor.withValues(alpha: 0.5)
                      : PiligrimColors.divider,
                ),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    cat.totemAsset,
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(
                      active ? cat.accentColor : PiligrimColors.sky.withValues(alpha: 0.3),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.title,
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: active
                          ? cat.accentColor
                          : PiligrimColors.sky.withValues(alpha: 0.45),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w300,
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

// ─────────────────────────────────────────────────────────────────────────────
// Фильтры
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.active, required this.onToggle});
  final Set<DishTag> active;
  final ValueChanged<DishTag> onToggle;

  static const _filters = [
    DishTag.vegan,
    DishTag.glutenFree,
    DishTag.spicy,
    DishTag.signature,
    DishTag.halal,
  ];

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty && _filters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tag = _filters[i];
          final isActive = active.contains(tag);
          return PiligrimTap(
            onTap: () => onToggle(tag),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: 180.ms,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? tag.color.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? tag.color.withValues(alpha: 0.5)
                      : PiligrimColors.divider,
                ),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    tag.iconAsset,
                    width: 11,
                    height: 11,
                    colorFilter: ColorFilter.mode(
                      isActive ? tag.color : PiligrimColors.sky.withValues(alpha: 0.3),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tag.label,
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isActive ? tag.color : PiligrimColors.sky.withValues(alpha: 0.35),
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

// ─────────────────────────────────────────────────────────────────────────────
// Карточка классического меню
// ─────────────────────────────────────────────────────────────────────────────
class _ClassicDishCard extends StatelessWidget {
  const _ClassicDishCard({
    required this.dish,
    this.animationDelay = Duration.zero,
  });

  final Dish dish;
  final Duration animationDelay;

  @override
  Widget build(BuildContext context) {
    final cat = categoryById(dish.categoryId);

    return PiligrimTap(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DishDetailSheetProxy(dish: dish),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PiligrimColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              // Кинематографическое изображение (заглушка)
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _CinemaThumbnailPainter(
                        colors: dish.gradientColors,
                      ),
                    ),
                    Center(
                      child: SvgPicture.asset(
                        dish.totemAsset,
                        width: 44,
                        height: 44,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withValues(alpha: 0.12),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    // Верхняя акцентная линия
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: cat.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Информация
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Название
                      Text(
                        dish.name,
                        style: PiligrimTextStyles.heading.copyWith(
                          fontSize: 15,
                          color: PiligrimColors.sky,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Описание
                      Text(
                        dish.description.replaceAll('\n', ' '),
                        style: PiligrimTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: PiligrimColors.sky.withValues(alpha: 0.45),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // Теги + цена
                      Row(
                        children: [
                          ...dish.tags.take(2).map(
                                (tag) => Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: SvgPicture.asset(
                                tag.iconAsset,
                                width: 14,
                                height: 14,
                                colorFilter: ColorFilter.mode(
                                  tag.color.withValues(alpha: 0.7),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${dish.price} ₸',
                            style: PiligrimTextStyles.button.copyWith(
                              color: PiligrimColors.steppe,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.04, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// Тонкий CustomPainter для thumbnail в классическом меню
class _CinemaThumbnailPainter extends CustomPainter {
  const _CinemaThumbnailPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final base = colors.isNotEmpty ? colors[0] : PiligrimColors.earthDeep;
    final accent = colors.length > 1 ? colors[1] : base;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = base);

    final shader = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: [accent.withValues(alpha: 0.7), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_CinemaThumbnailPainter old) => false;
}

// Прокси для показа detail sheet из классики
// (DishDetailSheet находится в dish_video_card.dart, дублируем структуру)
class _DishDetailSheetProxy extends StatelessWidget {
  const _DishDetailSheetProxy({required this.dish});
  final Dish dish;

  @override
  Widget build(BuildContext context) {
    // Переиспользуем класс из dish_video_card через bottom sheet
    final cat = categoryById(dish.categoryId);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 38,
              height: 3,
              decoration: BoxDecoration(
                color: PiligrimColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _CinemaThumbnailPainter(colors: dish.gradientColors),
                      ),
                      Center(
                        child: SvgPicture.asset(
                          dish.totemAsset,
                          width: 70,
                          height: 70,
                          colorFilter: ColorFilter.mode(
                            Colors.white.withValues(alpha: 0.12),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(cat.totemAsset, width: 13, height: 13,
                          colorFilter: ColorFilter.mode(cat.accentColor, BlendMode.srcIn)),
                      const SizedBox(width: 7),
                      Text(cat.title.toUpperCase(),
                          style: PiligrimTextStyles.caption.copyWith(
                            color: cat.accentColor.withValues(alpha: 0.8),
                            fontSize: 10, letterSpacing: 2.0,
                          )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(dish.name, style: PiligrimTextStyles.title.copyWith(
                    color: PiligrimColors.sky, fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(dish.nameSub, style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.steppe.withValues(alpha: 0.7))),
                  const SizedBox(height: 16),
                  Row(children: [
                    _InfoChip2(label: dish.weight, icon: 'assets/images/stone.svg'),
                    const SizedBox(width: 8),
                    _InfoChip2(label: '${dish.price} ₸',
                        icon: 'assets/images/zerno.svg', accent: true),
                  ]),
                  const SizedBox(height: 16),
                  if (dish.tags.isNotEmpty) ...[
                    Wrap(spacing: 7, runSpacing: 6,
                      children: dish.tags.map((t) => _TagChip2(tag: t)).toList()),
                    const SizedBox(height: 16),
                  ],
                  PiligrimInfoSection(title: 'О блюде', icon: 'assets/images/spiral.svg',
                      content: dish.description.replaceAll('\n', ' ')),
                  const SizedBox(height: 14),
                  PiligrimInfoSection(title: 'История', icon: 'assets/images/cobyz.svg',
                      content: dish.story, accent: true),
                  if (dish.allergens.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    PiligrimInfoSection(title: 'Аллергены', icon: 'assets/images/luk.svg',
                        content: dish.allergens.join(' · ')),
                  ],
                  const SizedBox(height: 24),
                  DishBookingCta(dish: dish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Локальные мини-виджеты для proxy sheet
class _InfoChip2 extends StatelessWidget {
  const _InfoChip2({required this.label, required this.icon, this.accent = false});
  final String label; final String icon; final bool accent;
  @override
  Widget build(BuildContext context) {
    final color = accent ? PiligrimColors.steppe : PiligrimColors.water;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(icon, width: 13, height: 13,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        const SizedBox(width: 5),
        Text(label, style: PiligrimTextStyles.caption.copyWith(
            color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _TagChip2 extends StatelessWidget {
  const _TagChip2({required this.tag});
  final DishTag tag;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(color: tag.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tag.color.withValues(alpha: 0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      SvgPicture.asset(tag.iconAsset, width: 11, height: 11,
          colorFilter: ColorFilter.mode(tag.color, BlendMode.srcIn)),
      const SizedBox(width: 4),
      Text(tag.label, style: PiligrimTextStyles.caption.copyWith(
          color: tag.color, fontSize: 10)),
    ]),
  );
}

// _Section2 заменён на PiligrimInfoSection (lib/widgets/piligrim_info_section.dart)
