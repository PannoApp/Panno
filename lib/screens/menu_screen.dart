// Экран Меню — «Основной путь»
// Режим 1: Видео-лента (Reels-style PageView)
// Режим 2: Классическое меню с поиском, фильтрами и инфинит-скроллом
// Состояние режима и данные управляются через MenuProvider (блок 5).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/menu_data.dart';
import '../core/theme.dart';
import '../data/models/api_category.dart';
import '../data/models/api_dish.dart';
import '../data/models/api_tag.dart';
import '../providers/menu_provider.dart';
import '../widgets/dish_elements.dart';
import '../widgets/dish_video_card.dart';
import '../widgets/error_view.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, this.isTabActive = true});

  final bool isTabActive;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final menuProvider = context.watch<MenuProvider>();

    if (!menuProvider.loaded) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PiligrimBackground(
            textureOpacity: 0.45,
            vignetteIntensity: 0.25,
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
            child: menuProvider.mode == MenuViewMode.feed
                ? _VideoFeedSection(key: const ValueKey('feed'), isTabActive: widget.isTabActive)
                : const _ClassicMenuSection(key: ValueKey('classic')),
          ),

          // Header (поверх контента)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MenuHeader(
              mode: menuProvider.mode,
              onModeChanged: context.read<MenuProvider>().setMode,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — caps-заголовок «МЕНЮ» + переключатель режимов
// ─────────────────────────────────────────────────────────────────────────────
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.mode, required this.onModeChanged});
  final MenuViewMode mode;
  final ValueChanged<MenuViewMode> onModeChanged;

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _MenuTitleBlock(),
            const Spacer(),
            _ModeSwitcher(mode: mode, onChanged: onModeChanged),
          ],
        ),
      ),
    );
  }
}

// Тотем + caps «МЕНЮ» + тонкая steppe-hairline (единый штрих с section headers).
class _MenuTitleBlock extends StatelessWidget {
  const _MenuTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
            color: PiligrimColors.steppe.withValues(alpha: 0.78),
            letterSpacing: 3.0,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        // Хайрлайн steppe → transparent — фирменный «нить пути»
        Container(
          width: 56,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PiligrimColors.steppe.withValues(alpha: 0.55),
                PiligrimColors.steppe.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Переключатель режимов меню: «Путь» (видео) ↔ «Свиток» (классика)
// Sliding water-pill indicator с плавной анимацией 280ms easeOutCubic.
class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});
  final MenuViewMode mode;
  final ValueChanged<MenuViewMode> onChanged;

  static const double _height = 36;
  static const double _radius = 18;
  static const double _trackWidth = 184;

  @override
  Widget build(BuildContext context) {
    final isFeed = mode == MenuViewMode.feed;

    return SizedBox(
      width: _trackWidth,
      height: _height,
      child: Stack(
        children: [
          // Фон-«дорожка»
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PiligrimColors.earthDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: PiligrimColors.divider),
              ),
            ),
          ),
          // Скользящий water-индикатор
          AnimatedAlign(
            duration: 280.ms,
            curve: Curves.easeOutCubic,
            alignment: isFeed ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: _trackWidth / 2,
              height: _height,
              decoration: BoxDecoration(
                color: PiligrimColors.water.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: PiligrimColors.water.withValues(alpha: 0.5),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PiligrimColors.water.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
          // Тапы и подписи
          Row(
            children: [
              Expanded(
                child: _ModeTabLabel(
                  label: 'Видео',
                  active: isFeed,
                  onTap: () => onChanged(MenuViewMode.feed),
                ),
              ),
              Expanded(
                child: _ModeTabLabel(
                  label: 'Фото',
                  active: !isFeed,
                  onTap: () => onChanged(MenuViewMode.classic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Подпись + иконка одной из двух вкладок mode switcher.
class _ModeTabLabel extends StatelessWidget {
  const _ModeTabLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? PiligrimColors.water
        : PiligrimColors.sky.withValues(alpha: 0.45);

    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_ModeSwitcher._radius),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: 220.ms,
          curve: Curves.easeOut,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 11.5,
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w300,
            letterSpacing: active ? 0.6 : 0.4,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// РЕЖИМ 1: ВИДЕО-ЛЕНТА
// ─────────────────────────────────────────────────────────────────────────────
class _VideoFeedSection extends StatefulWidget {
  const _VideoFeedSection({super.key, this.isTabActive = true});

  final bool isTabActive;

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
    final menuProvider = context.watch<MenuProvider>();
    final dishes = menuProvider.feedDishes;

    // Пока блюда загружаются — показываем индикатор
    if (menuProvider.isLoadingFeed && dishes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: PiligrimColors.steppe),
      );
    }

    if (menuProvider.feedError != null && dishes.isEmpty) {
      return ErrorView(
        message: menuProvider.feedError!,
        onRetry: () => context.read<MenuProvider>().retry(),
      );
    }

    if (dishes.isEmpty) {
      return Center(
        child: Text(
          'Меню скоро появится',
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          onPageChanged: (i) {
            setState(() => _currentPage = i);
            final provider = context.read<MenuProvider>();
            if (i >= dishes.length - 2 &&
                provider.hasMoreFeed &&
                !provider.isLoadingFeed) {
              provider.loadFeed();
            }
          },
          itemCount: dishes.length,
          itemBuilder: (_, i) => DishVideoCard(
            dish: dishes[i],
            isActive: i == _currentPage && widget.isTabActive,
          ),
        ),

        // Вертикальный прогресс-индикатор справа
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _VerticalProgressDots(
              count: dishes.length,
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
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Инфинит-скролл: при приближении к концу списка загружаем следующую страницу
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final provider = context.read<MenuProvider>();
    if (!provider.hasMore || provider.isLoadingMore) return;

    final max = _scrollCtrl.position.maxScrollExtent;
    final pos = _scrollCtrl.position.pixels;
    if (pos >= max - 200) {
      provider.loadDishes();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final top = MediaQuery.paddingOf(context).top;
    final dishes = menuProvider.dishes;

    // Группируем по категориям только когда нет ни фильтров, ни поиска.
    final shouldGroup = menuProvider.activeCategoryId == null &&
        menuProvider.searchQuery.isEmpty &&
        menuProvider.activeTagIds.isEmpty;

    final classicItems = _buildClassicItems(
      dishes: dishes,
      categories: menuProvider.categories,
      group: shouldGroup,
    );

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + 70)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _SearchBar(
              controller: _searchCtrl,
              onChanged: context.read<MenuProvider>().setSearch,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _CategoryTabs(
            categories: menuProvider.categories,
            activeCategoryId: menuProvider.activeCategoryId,
            onSelect: context.read<MenuProvider>().setCategory,
          ),
        ),

        SliverToBoxAdapter(
          child: _FilterChips(
            tags: menuProvider.availableTags,
            activeIds: menuProvider.activeTagIds,
            onToggle: (tag) => menuProvider.toggleTag(tag.id),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        if (menuProvider.isLoading && dishes.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: PiligrimColors.steppe),
            ),
          )
        else if (menuProvider.error != null && dishes.isEmpty)
          SliverErrorView(
            message: menuProvider.error!,
            onRetry: () => context.read<MenuProvider>().retry(),
          )
        else if (dishes.isEmpty)
          const SliverFillRemaining(child: _ClassicEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => classicItems[i],
                childCount: classicItems.length,
              ),
            ),
          ),

        if (menuProvider.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: PiligrimColors.steppe,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // Собирает список Sliver-айтемов:
  // — если group=true: чередует заголовки секций (steppe-line) и карточки блюд
  // — иначе: плоский список карточек.
  // Сохраняет инкрементальную animation-delay, чтобы fade-in волной шёл сверху вниз.
  List<Widget> _buildClassicItems({
    required List<ApiDish> dishes,
    required List<ApiCategory> categories,
    required bool group,
  }) {
    final items = <Widget>[];
    final categoryName = <int, String>{
      for (final c in categories) c.id: c.name,
    };

    if (!group) {
      for (var i = 0; i < dishes.length; i++) {
        items.add(_ClassicDishCard(
          dish: dishes[i],
          categoryName: categoryName[dishes[i].category],
          animationDelay: Duration(milliseconds: i * 40),
        ));
      }
      return items;
    }

    // Группируем блюда по category id, сохраняя порядок появления.
    final orderedIds = <int>[];
    final groups = <int, List<ApiDish>>{};
    for (final d in dishes) {
      if (!groups.containsKey(d.category)) {
        orderedIds.add(d.category);
        groups[d.category] = [];
      }
      groups[d.category]!.add(d);
    }

    // Сортируем по order из ApiCategory; неизвестные id уходят в конец.
    final orderById = <int, int>{
      for (final c in categories) c.id: c.order,
    };
    orderedIds.sort((a, b) {
      final oa = orderById[a] ?? 1 << 30;
      final ob = orderById[b] ?? 1 << 30;
      return oa.compareTo(ob);
    });

    var dishIndex = 0;
    for (final id in orderedIds) {
      final name = categoryName[id] ?? '';
      if (name.isEmpty) continue;
      items.add(_CategorySectionHeader(name: name));
      for (final dish in groups[id]!) {
        items.add(_ClassicDishCard(
          dish: dish,
          categoryName: name,
          animationDelay: Duration(milliseconds: dishIndex * 35),
        ));
        dishIndex++;
      }
    }
    return items;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Заголовок секции категории — caps + steppe-hairline
// «Тонкая нить пути» по горизонтали справа от текста.
// ─────────────────────────────────────────────────────────────────────────────
class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            name.toUpperCase(),
            style: PiligrimTextStyles.sectionLabel.copyWith(
              color: PiligrimColors.steppe.withValues(alpha: 0.82),
              letterSpacing: 2.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.45),
                    PiligrimColors.steppe.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 450.ms, curve: Curves.easeOut)
        .slideY(begin: 0.12, end: 0, duration: 450.ms, curve: Curves.easeOut);
  }
}

// Пустое состояние «Блюда не найдены» — тотем + caption.
class _ClassicEmptyState extends StatelessWidget {
  const _ClassicEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 44,
            height: 44,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.22),
              BlendMode.srcIn,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then()
              .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 2600.ms),
          const SizedBox(height: 16),
          Text(
            'Блюда не найдены',
            style: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.45),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'попробуйте сменить фильтр или поиск',
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Поисковая строка — water-иконка, focus-glow, clear-кнопка (×)
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_handleFocus);
    widget.controller.addListener(_handleText);
    _hasText = widget.controller.text.isNotEmpty;
  }

  void _handleFocus() {
    if (_focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  void _handleText() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleText);
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _focused
        ? PiligrimColors.water.withValues(alpha: 0.85)
        : PiligrimColors.water.withValues(alpha: 0.45);

    return AnimatedContainer(
      duration: 220.ms,
      curve: Curves.easeOut,
      height: 46,
      decoration: BoxDecoration(
        color: PiligrimColors.earth,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused
              ? PiligrimColors.water.withValues(alpha: 0.55)
              : PiligrimColors.steppe.withValues(alpha: 0.2),
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: PiligrimColors.water.withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SvgPicture.asset(
            'assets/images/luk.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 14,
                color: PiligrimColors.nomadCream,
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
          AnimatedSwitcher(
            duration: 180.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: _hasText
                ? PiligrimTap(
                    key: const ValueKey('clear'),
                    onTap: _clear,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: PiligrimColors.sky.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('empty'),
                    width: 6,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Категории (горизонтальный скролл) — данные из API (ApiCategory)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.activeCategoryId,
    required this.onSelect,
  });

  final List<ApiCategory> categories;
  final int? activeCategoryId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    // «Все блюда» — специальная вкладка с id = null
    final allActive = activeCategoryId == null;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _CategoryTab(
              label: 'Все блюда',
              active: allActive,
              onTap: () => onSelect(null),
            );
          }
          final cat = categories[i - 1];
          return _CategoryTab(
            label: cat.name,
            active: activeCategoryId == cat.id,
            onTap: () => onSelect(cat.id),
          );
        },
      ),
    );
  }
}

// Pill-вкладка категории — полный round, steppe-акцент в активном состоянии.
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: 220.ms,
        curve: Curves.easeOut,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? PiligrimColors.steppe.withValues(alpha: 0.18)
              : PiligrimColors.earth.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? PiligrimColors.steppe.withValues(alpha: 0.6)
                : PiligrimColors.divider,
            width: active ? 0.9 : 0.5,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: 220.ms,
          curve: Curves.easeOut,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 12,
            color: active
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: 0.5),
            fontWeight: active ? FontWeight.w700 : FontWeight.w300,
            letterSpacing: active ? 0.6 : 0.3,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Фильтры по тегам (клиентские)
// ─────────────────────────────────────────────────────────────────────────────
// Динамические фильтр-чипы — теги приходят из API, не хардкодятся.
// Новый тег в админке → сразу виден в приложении без обновления.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.tags,
    required this.activeIds,
    required this.onToggle,
  });

  final List<ApiTag> tags;
  final Iterable<int> activeIds;
  final ValueChanged<ApiTag> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final isActive = activeIds.contains(tag.id);
          final style = tagStyleFor(tag.name);
          return PiligrimTap(
            onTap: () => onToggle(tag),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: 200.ms,
              curve: Curves.easeOut,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? style.color.withValues(alpha: 0.22)
                    : PiligrimColors.earth.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? style.color.withValues(alpha: 0.55)
                      : PiligrimColors.divider,
                  width: isActive ? 0.9 : 0.5,
                ),
              ),
              child: AnimatedDefaultTextStyle(
                duration: 200.ms,
                style: PiligrimTextStyles.caption.copyWith(
                  fontSize: 11.5,
                  color: isActive
                      ? style.color
                      : PiligrimColors.sky.withValues(alpha: 0.45),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w300,
                  letterSpacing: isActive ? 0.45 : 0.2,
                ),
                child: Text(tag.name),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Карточка классического меню (ApiDish)
// — pill-badge категории, многоступенчатый gradient, премиальная цена-pill.
// ─────────────────────────────────────────────────────────────────────────────
class _ClassicDishCard extends StatelessWidget {
  const _ClassicDishCard({
    required this.dish,
    this.categoryName,
    this.animationDelay = Duration.zero,
  });

  final ApiDish dish;
  final String? categoryName;
  final Duration animationDelay;

  String _formatPrice(int price) =>
      price.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]} ',
          );

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      borderRadius: BorderRadius.zero,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DishDetailSheet(dish: dish),
      ),
      child: Container(
        color: PiligrimColors.earth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [1] Фото — full-width Stack с многоступенчатым градиентом и UI-overlay.
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: dish.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: dish.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _ClassicThumbnailFallback(),
                          errorWidget: (_, __, ___) => const _ClassicThumbnailFallback(),
                        )
                      : const _ClassicThumbnailFallback(),
                ),
                // Многоступенчатый bottom gradient — гарантирует читаемость цены/категории.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x331C1510),
                          Color(0xCC1C1510),
                          Color(0xF21C1510),
                        ],
                        stops: [0.0, 0.45, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
                // Pill-badge категории — caps, тёплая прозрачная подложка.
                if (categoryName != null && categoryName!.isNotEmpty)
                  Positioned(
                    top: 14,
                    left: 16,
                    child: _CategoryPillBadge(name: categoryName!),
                  ),
                // Цена — premium pill внизу слева, тёплая steppe-обводка.
                Positioned(
                  bottom: 14,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD61C1510),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: PiligrimColors.steppe.withValues(alpha: 0.55),
                        width: 0.9,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PiligrimColors.shadow.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_formatPrice(dish.price)} ₸',
                      style: const TextStyle(
                        fontFamily: PiligrimFonts.museoSans,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PiligrimColors.steppe,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // [2] Текстовый блок с левым медным акцентом
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: PiligrimColors.earth,
                border: Border(
                  left: BorderSide(
                    color: PiligrimColors.steppe.withValues(alpha: 0.55),
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 13, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 17,
                      color: PiligrimColors.nomadCream,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dish.description.replaceAll('\n', ' '),
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dish.tags.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: dish.tags.take(3).map((tag) {
                        final style = tagStyleFor(tag.name);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              style.iconAsset,
                              width: 11,
                              height: 11,
                              colorFilter: ColorFilter.mode(
                                style.color.withValues(alpha: 0.7),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tag.name,
                              style: PiligrimTextStyles.micro.copyWith(
                                color: style.color.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Разделитель между карточками
            Container(
              height: 1,
              color: PiligrimColors.divider,
            ),
          ],
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.04, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// Pill-badge категории — caps name, sky цвет, тонкий water-border.
// Используется поверх изображения в классической карточке.
class _CategoryPillBadge extends StatelessWidget {
  const _CategoryPillBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PiligrimColors.water.withValues(alpha: 0.38),
          width: 0.7,
        ),
      ),
      child: Text(
        name.toUpperCase(),
        style: PiligrimTextStyles.micro.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.9),
          fontSize: 10,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Gradient-заглушка для thumbnail (когда нет imageUrl)
class _ClassicThumbnailFallback extends StatelessWidget {
  const _ClassicThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PiligrimColors.earth,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/bird_totem (1).svg',
          width: 44,
          height: 44,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.12),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Детальный лист блюда (используется в классическом режиме)
// ─────────────────────────────────────────────────────────────────────────────
class _DishDetailSheet extends StatelessWidget {
  const _DishDetailSheet({required this.dish});
  final ApiDish dish;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earth,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // [1] Фото — полная ширина
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: dish.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: dish.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const _ClassicThumbnailFallback(),
                  ),
                ),
                // Градиент снизу фото
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xF01C1510)],
                        stops: [0.35, 1.0],
                      ),
                    ),
                  ),
                ),
                // Handle вверху по центру
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Цена — pill внизу слева
                Positioned(
                  bottom: 16,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1C1510),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: PiligrimColors.steppe.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${dish.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
                      style: const TextStyle(
                        fontFamily: PiligrimFonts.museoSans,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PiligrimColors.steppe,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // [2] Контент
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                children: [
                  // Название
                  Text(
                    dish.name,
                    style: PiligrimTextStyles.title.copyWith(
                      fontSize: 24,
                      color: PiligrimColors.nomadCream,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Вес — просто текст
                  if (dish.weight.isNotEmpty)
                    Text(
                      '${dish.weight} г',
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 20),

                  const Divider(color: PiligrimColors.divider, height: 1),

                  const SizedBox(height: 20),

                  // Описание
                  Text(
                    dish.description.replaceAll('\n', ' '),
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),

                  // История
                  if (dish.story.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('ИСТОРИЯ', style: PiligrimTextStyles.sectionLabel),
                    const SizedBox(height: 8),
                    Text(
                      dish.story,
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.steppe.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Аллергены
                  if (dish.allergens.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('АЛЛЕРГЕНЫ', style: PiligrimTextStyles.sectionLabel),
                    const SizedBox(height: 8),
                    Text(
                      dish.allergens.join(' · '),
                      style: PiligrimTextStyles.caption.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Теги
                  if (dish.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: dish.tags.map((t) => DishCardTagChip(tag: t)).toList(),
                    ),
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
