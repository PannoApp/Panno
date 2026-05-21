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
// HEADER — переключатель режимов
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
          children: [
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
                    color: PiligrimColors.steppe.withValues(alpha: 0.7),
                    letterSpacing: 3.0,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Spacer(),
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
  final MenuViewMode mode;
  final ValueChanged<MenuViewMode> onChanged;

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
            active: mode == MenuViewMode.feed,
            onTap: () => onChanged(MenuViewMode.feed),
            radius: const BorderRadius.horizontal(left: Radius.circular(9)),
          ),
          _ModeTab(
            label: 'Свиток',
            icon: 'assets/images/spiral.svg',
            active: mode == MenuViewMode.classic,
            onTap: () => onChanged(MenuViewMode.classic),
            radius: const BorderRadius.horizontal(right: Radius.circular(9)),
          ),
        ],
      ),
    );
  }
}

// Одна вкладка переключателя режима
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
              ? PiligrimColors.steppe.withValues(alpha: 0.15)
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
                active
                    ? PiligrimColors.steppe
                    : PiligrimColors.sky.withValues(alpha: 0.3),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                color: active
                    ? PiligrimColors.steppe
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
    final filtered = menuProvider.dishes;

    return CustomScrollView(
      controller: _scrollCtrl,
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
              onChanged: context.read<MenuProvider>().setSearch,
            ),
          ),
        ),

        // Категории из API (+ «Все блюда»)
        SliverToBoxAdapter(
          child: _CategoryTabs(
            categories: menuProvider.categories,
            activeCategoryId: menuProvider.activeCategoryId,
            onSelect: context.read<MenuProvider>().setCategory,
          ),
        ),

        // Фильтры по тегам (динамические из API, серверная фильтрация)
        SliverToBoxAdapter(
          child: _FilterChips(
            tags: menuProvider.availableTags,
            activeIds: menuProvider.activeTagIds,
            onToggle: (tag) => menuProvider.toggleTag(tag.id),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Индикатор первичной загрузки
        if (menuProvider.isLoading && filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: PiligrimColors.steppe),
            ),
          )
        else if (menuProvider.error != null && filtered.isEmpty)
          SliverErrorView(
            message: menuProvider.error!,
            onRetry: () => context.read<MenuProvider>().retry(),
          )
        else if (filtered.isEmpty)
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
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ClassicDishCard(
                  dish: filtered[i],
                  animationDelay: Duration(milliseconds: i * 50),
                ),
                childCount: filtered.length,
              ),
            ),
          ),

        // Индикатор подгрузки следующей страницы
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

        // Нижний отступ (под bottom nav bar)
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
      height: 46,
      decoration: BoxDecoration(
        color: PiligrimColors.earth,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          SvgPicture.asset(
            'assets/images/luk.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.45),
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
              cursorColor: PiligrimColors.steppe,
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            // Вкладка «Все блюда»
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active
              ? PiligrimColors.steppe.withValues(alpha: 0.14)
              : PiligrimColors.earth,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? PiligrimColors.steppe.withValues(alpha: 0.5)
                : PiligrimColors.divider,
          ),
        ),
        child: Text(
          label,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 12,
            color: active
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: 0.45),
            fontWeight: active ? FontWeight.w700 : FontWeight.w300,
          ),
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
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final isActive = activeIds.contains(tag.id);
          final style = tagStyleFor(tag.name);
          return PiligrimTap(
            onTap: () => onToggle(tag),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: 180.ms,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? style.color.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? style.color.withValues(alpha: 0.5)
                      : PiligrimColors.divider,
                ),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    style.iconAsset,
                    width: 11,
                    height: 11,
                    colorFilter: ColorFilter.mode(
                      isActive
                          ? style.color
                          : PiligrimColors.sky.withValues(alpha: 0.3),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tag.name,
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isActive
                          ? style.color
                          : PiligrimColors.sky.withValues(alpha: 0.35),
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
// Карточка классического меню (ApiDish)
// ─────────────────────────────────────────────────────────────────────────────
class _ClassicDishCard extends StatelessWidget {
  const _ClassicDishCard({
    required this.dish,
    this.animationDelay = Duration.zero,
  });

  final ApiDish dish;
  final Duration animationDelay;

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
            // [1] Фото — full-width Stack с градиентом и ценой
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
                // Градиент снизу — глубже, теплее
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE81C1510)],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Цена — pill с рамкой внизу слева
                Positioned(
                  bottom: 14,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1C1510),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: PiligrimColors.steppe.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${dish.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} ₸',
                      style: const TextStyle(
                        fontFamily: PiligrimFonts.museoSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PiligrimColors.steppe,
                        letterSpacing: 0.5,
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
