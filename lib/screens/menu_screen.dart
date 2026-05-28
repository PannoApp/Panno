// Экран Меню — «Основной путь»
// Режим 1: Видео-лента (Reels-style PageView)
// Режим 2: Классическое меню с поиском, фильтрами и инфинит-скроллом
// Состояние режима и данные управляются через MenuProvider (блок 5).
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/menu_data.dart';
import '../core/piligrim_route.dart';
import '../core/theme.dart';
import '../data/models/api_category.dart';
import '../data/models/api_dish.dart';
import '../data/models/api_tag.dart';
import '../providers/auth_provider.dart';
import '../providers/menu_provider.dart';
import 'dish_edit_screen.dart';
import '../widgets/dish_detail_sheet.dart';
import '../widgets/dish_video_card.dart';
import '../widgets/error_view.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tab_editorial_mark.dart';
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

    if (!menuProvider.loaded ||
        (menuProvider.isBootstrapping && menuProvider.bootstrapError == null)) {
      return const _MenuLoadingSkeleton();
    }

    if (menuProvider.bootstrapError != null) {
      return Scaffold(
        backgroundColor: PiligrimColors.earth,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PiligrimBackground(
              textureOpacity: 0.45,
              vignetteIntensity: 0.25,
            ),
            ErrorView(
              message: menuProvider.bootstrapError!,
              onRetry: () => context.read<MenuProvider>().retry(),
            ),
          ],
        ),
      );
    }

    final isClassic = menuProvider.mode == MenuViewMode.classic;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom -
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: AnimatedOpacity(
          opacity: (isClassic && isAdmin) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !(isClassic && isAdmin),
            child: FloatingActionButton(
              backgroundColor: PiligrimColors.earthWarm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: PiligrimColors.water.withValues(alpha: 0.35),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  PiligrimPageRoute(
                    builder: (context) => DishEditScreen(
                      dish: null,
                      categories: menuProvider.categories,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add, color: PiligrimColors.water),
            ),
          ),
        ),
      ),
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
    final isFeed = mode == MenuViewMode.feed;
    const markToControlsGap = PiligrimSpacing.tabEditorialMarkGap;

    return ClipRect(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          PiligrimLayout.tabContentTop(context),
          20,
          isFeed ? 10 : 14,
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: PiligrimTabEditorialMark(label: 'MENU', compact: true),
            ),
            const SizedBox(height: markToControlsGap),
            Align(
              alignment: Alignment.centerRight,
              child: _ModeSwitcher(mode: mode, onChanged: onModeChanged),
            ),
          ],
        ),
      ),
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
  /// Внутренний воздух между track border и active pill (Apple-style inset).
  static const double _pillInset = 3;

  @override
  Widget build(BuildContext context) {
    final isFeed = mode == MenuViewMode.feed;
    const innerWidth = _trackWidth - _pillInset * 2;
    const pillWidth = innerWidth / 2;
    const pillRadius = _radius - _pillInset;

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
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_pillInset),
              child: AnimatedAlign(
                duration: 280.ms,
                curve: Curves.easeOutCubic,
                alignment:
                    isFeed ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: PiligrimColors.water.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(pillRadius),
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
  int? _lastAppliedFeedStart;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _maybeJumpToFeedStart(MenuProvider provider, int dishCount) {
    final idx = provider.feedStartIndex;
    if (idx == null || idx == _lastAppliedFeedStart || dishCount == 0) return;
    _lastAppliedFeedStart = idx;
    final target = idx.clamp(0, dishCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(target);
        setState(() => _currentPage = target);
      }
      provider.clearFeedStartIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final dishes = menuProvider.feedDishes;
    _maybeJumpToFeedStart(menuProvider, dishes.length);

    if (menuProvider.isLoadingFeed && dishes.isEmpty) {
      return const Center(child: PiligrimLoader(color: PiligrimColors.steppe));
    }

    if (menuProvider.feedError != null && dishes.isEmpty) {
      return ErrorView(
        message: menuProvider.feedError!,
        onRetry: () => context.read<MenuProvider>().retry(),
      );
    }

    if (dishes.isEmpty) {
      return const _FeedEmptyState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
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

// Умные точки прокрутки — максимум 7 виртуальных, current всегда в центре.
// При count <= 7 рисует все точки; при > 7 — виртуальный слайдинг-вид.
class _VerticalProgressDots extends StatelessWidget {
  const _VerticalProgressDots({required this.count, required this.current});
  final int count;
  final int current;

  static const int _maxDots = 7;
  static const int _halfWindow = _maxDots ~/ 2;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    final visibleCount = count.clamp(0, _maxDots);
    // Смещение окна: держим current в центре насколько возможно
    final windowStart = (count <= _maxDots)
        ? 0
        : (current - _halfWindow).clamp(0, count - _maxDots);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(visibleCount, (i) {
        final realIndex = windowStart + i;
        final active = realIndex == current;
        // Точки на краях окна чуть прозрачнее для эффекта fade-out
        final isEdge = count > _maxDots && (i == 0 || i == visibleCount - 1);
        return AnimatedContainer(
          duration: 220.ms,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          width: 2.5,
          height: active ? 18 : 5,
          decoration: BoxDecoration(
            color: active
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: isEdge ? 0.1 : 0.15),
            borderRadius: BorderRadius.circular(2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: PiligrimColors.steppe.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
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
      physics: null,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).top +
                PiligrimSpacing.menuHeaderExtentBelowSafeArea,
          ),
        ),

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
          const SliverToBoxAdapter(child: _ClassicMenuSkeleton())
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
              child: Center(child: PiligrimLoader(size: 24, color: PiligrimColors.steppe)),
            ),
          ),

        // Маркер конца списка — «путь изучен»
        if (!menuProvider.hasMore && dishes.isNotEmpty)
          SliverToBoxAdapter(
            child: _EndOfListMarker(count: dishes.length),
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
    final isAdmin = context.read<AuthProvider>().isAdmin;

    if (!group) {
      for (var i = 0; i < dishes.length; i++) {
        items.add(_ClassicDishCard(
          dish: dishes[i],
          categoryName: categoryName[dishes[i].category],
          animationDelay: Duration(milliseconds: i * 40),
          isAdmin: isAdmin,
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
          isAdmin: isAdmin,
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
// Маркер конца списка — spiral тотем + «N блюд · путь изучен».
// ─────────────────────────────────────────────────────────────────────────────
class _EndOfListMarker extends StatelessWidget {
  const _EndOfListMarker({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.18),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$count блюд · путь изучен',
            style: PiligrimTextStyles.micro.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.28),
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton-заглушка классического меню — 3 placeholder-карточки с breathing.
// Заменяет одинокий spinner при первой загрузке данных.
// ─────────────────────────────────────────────────────────────────────────────
class _ClassicMenuSkeleton extends StatelessWidget {
  const _ClassicMenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) => _SkeletonCard(delay: Duration(milliseconds: i * 180))),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.delay});
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: PiligrimColors.earthWarm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PiligrimColors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Изображение-заглушка
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: PiligrimColors.earthDeep),
              ),
              // Текстовый блок-заглушка
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Container(
                      height: 17,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: PiligrimColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Описание строка 1
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: PiligrimColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Описание строка 2 (короче)
                    Container(
                      height: 12,
                      width: MediaQuery.sizeOf(context).width * 0.55,
                      decoration: BoxDecoration(
                        color: PiligrimColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: delay, onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 1200.ms,
          curve: Curves.easeInOut,
          builder: (_, value, child) => Opacity(opacity: 0.4 + value * 0.5, child: child),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Пустое состояние видео-ленты — атмосфера бренда, тотем + кинематограф.
// ─────────────────────────────────────────────────────────────────────────────
class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Кинематографический фон — тёплое тёмное зарево
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0.15),
              radius: 0.85,
              colors: [
                PiligrimColors.glowAmber,
                PiligrimColors.earth,
              ],
            ),
          ),
        ),
        // Содержимое по центру
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/star_totem (1).svg',
                width: 64,
                height: 64,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.steppe.withValues(alpha: 0.3),
                  BlendMode.srcIn,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 800.ms)
                  .then()
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.04, 1.04),
                    duration: 2800.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                'Путь ожидает',
                style: PiligrimTextStyles.title.copyWith(
                  color: PiligrimColors.nomadCream.withValues(alpha: 0.45),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Видео ещё готовятся',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.3),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 20),
              PiligrimTap(
                onTap: () =>
                    context.read<MenuProvider>().setMode(MenuViewMode.classic),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.45),
                    ),
                    color: PiligrimColors.earthDeep.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    'Открыть меню с фото',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.water.withValues(alpha: 0.85),
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
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
                      child: Text(
                        '×',
                        style: TextStyle(
                          fontSize: 18,
                          color: PiligrimColors.sky.withValues(alpha: 0.5),
                          height: 1.0,
                          fontFamily: 'MuseoSans',
                        ),
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
void _openDishEdit(BuildContext context, ApiDish dish) {
  Navigator.of(context).push(
    PiligrimPageRoute(
      builder: (context) => DishEditScreen(
        dish: dish,
        categories: context.read<MenuProvider>().categories,
      ),
    ),
  );
}

class _ClassicDishCard extends StatelessWidget {
  const _ClassicDishCard({
    required this.dish,
    required this.isAdmin,
    this.categoryName,
    this.animationDelay = Duration.zero,
  });

  final ApiDish dish;
  final bool isAdmin;
  final String? categoryName;
  final Duration animationDelay;

  String _formatPrice(int price) =>
      price.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]} ',
          );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PiligrimTap(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ClassicDishDetailSheet(dish: dish),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: PiligrimColors.earthWarm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PiligrimColors.divider, width: 0.5),
              boxShadow: PiligrimShadows.card,
            ),
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
                              placeholder: (_, __) => const DishClassicThumbnailFallback(),
                              errorWidget: (_, __, ___) => const DishClassicThumbnailFallback(),
                          )
                        : const DishClassicThumbnailFallback(),
                    ),
                    // Верхний виньет — приглушает яркие фотографии и даёт атмосферность.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PiligrimColors.imageScrim.withValues(alpha: 0.31),
                              PiligrimColors.clear,
                            ],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                    // Многоступенчатый bottom gradient — гарантирует читаемость цены/категории.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PiligrimColors.clear,
                              PiligrimColors.imageScrim.withValues(alpha: 0.27),
                              PiligrimColors.imageScrim.withValues(alpha: 0.83),
                              PiligrimColors.imageScrim.withValues(alpha: 0.96),
                            ],
                            stops: const [0.0, 0.40, 0.80, 1.0],
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
                    if (isAdmin)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _AdminEditButton(
                          onTap: () => _openDishEdit(context, dish),
                        ),
                      ),
                    // Цена — premium pill внизу слева, тёплая steppe-обводка + ember-glow (огонь по ТЗ).
                    Positioned(
                      bottom: 14,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PiligrimColors.imageScrim.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.58),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: PiligrimColors.steppe.withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: 0,
                            ),
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

                // [2] Текстовый блок — steppe left-accent + pill tag badges.
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: PiligrimColors.earthWarm,
                      padding: const EdgeInsets.fromLTRB(20, 13, 16, 16),
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
                              fontSize: 12.5,
                              color: PiligrimColors.sky.withValues(alpha: 0.55),
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Steppe left-accent — «нить пути», фирменный штрих карточки.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PiligrimColors.steppe.withValues(alpha: 0.55),
                              PiligrimColors.steppe.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        color: PiligrimColors.cardOverlay,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PiligrimColors.water.withValues(alpha: 0.38),
          width: 0.8,
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

// Кнопка редактирования блюда для администратора — круглая 36×36 поверх изображения.
class _AdminEditButton extends StatelessWidget {
  const _AdminEditButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: PiligrimColors.water.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: const Icon(
          Icons.edit_outlined,
          size: 16,
          color: PiligrimColors.water,
        ),
      ),
    );
  }
}

// Скелетон загрузки меню — пульсирующий тотем на фоне бренда
// Показывается пока MenuProvider инициализирует режим из SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
class _MenuLoadingSkeleton extends StatefulWidget {
  const _MenuLoadingSkeleton();

  @override
  State<_MenuLoadingSkeleton> createState() => _MenuLoadingSkeletonState();
}

class _MenuLoadingSkeletonState extends State<_MenuLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PiligrimBackground(
            textureOpacity: 0.45,
            vignetteIntensity: 0.25,
          ),
          // Тёплое свечение снизу — огненный мотив
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.10),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          // Пульсирующий тотем по центру — SafeArea даёт оптический центр
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) {
                final t = _ctrl.value;
                final pulse = 0.55 + 0.45 * math.sin(t * math.pi);
                return Opacity(
                  opacity: (0.35 + pulse * 0.55).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.82 + pulse * 0.18,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.water
                                .withValues(alpha: pulse * 0.18),
                            blurRadius: 24,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/images/star_totem (1).svg',
                width: 48,
                height: 48,
                colorFilter: const ColorFilter.mode(
                  PiligrimColors.water,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
