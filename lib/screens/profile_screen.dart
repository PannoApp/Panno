// Экран Профиль / Контакты — «Карта Героя»
// Согласно ТЗ раздел 4.5 | Концепция «Modern Nomad»
// Textured header · water ripple · totem decorations · brand-styled toggles
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_guard.dart';
import '../core/theme.dart';
import '../core/profile_data.dart';
import '../providers/auth_provider.dart';
import '../providers/core_info_provider.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_section_header.dart';
import '../widgets/piligrim_tap.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Состояние toggles (в реальном приложении — через SharedPreferences / Provider)
  final Map<String, bool> _notifState = {
    'events': true,
    'promo': false,
    'private': true,
  };

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PiligrimColors.earthDeep,
            content: Text(
              'Не удалось открыть ссылку',
              style: PiligrimTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
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
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      user: user,
                      onStartJourney: () async {
                        await guardAuth(context);
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _StatsRow(user: user),
                    const SizedBox(height: 28),

                    // Push-уведомления
                    const PiligrimSectionHeader(
                      label: 'УВЕДОМЛЕНИЯ',
                      icon: 'assets/images/star_totem (1).svg',
                    ),
                    const SizedBox(height: 12),
                    _NotificationsCard(
                      state: _notifState,
                      onToggle: (id, val) =>
                          setState(() => _notifState[id] = val),
                    ),
                    const SizedBox(height: 28),

                    // Контакты
                    const PiligrimSectionHeader(
                      label: 'КОНТАКТЫ',
                      icon: 'assets/images/splash_path (1).svg',
                    ),
                    const SizedBox(height: 12),
                    _ContactsCard(onLaunch: _launch),
                    const SizedBox(height: 28),

                    // Часы работы
                    const PiligrimSectionHeader(
                      label: 'ЧАСЫ РАБОТЫ',
                      icon: 'assets/images/sun.svg',
                    ),
                    const SizedBox(height: 12),
                    _HoursCard(),
                    const SizedBox(height: 28),

                    // Правила посещения
                    const PiligrimSectionHeader(
                      label: 'ПРАВИЛА ПОСЕЩЕНИЯ',
                      icon: 'assets/images/shaman.svg',
                    ),
                    const SizedBox(height: 12),
                    _RulesCard(),
                    const SizedBox(height: 28),

                    // Юридическое + версия
                        _LegalFooter(onLaunch: _launch),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatefulWidget {
  const _HeroHeader({
    required this.user,
    required this.onStartJourney,
  });

  final HeroUser user;
  final Future<void> Function() onStartJourney;

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final authorized = widget.user.isAuthorized;

    return SizedBox(
      height: 230 + top,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Мягкое дыхание сверху — снизу бесшовно в Қара жер (без линии среза с лентой)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.11),
                    PiligrimColors.steppe.withValues(alpha: 0.035),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),

          // Призрачный тотем фон
          Positioned(
            right: -40,
            top: top - 20,
            child: AnimatedBuilder(
              animation: _rotCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _rotCtrl.value * 2 * 3.14159,
                child: child,
              ),
              child: SvgPicture.asset(
                'assets/images/wheel_totem (1).svg',
                width: 260,
                height: 260,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.steppe.withValues(alpha: 0.06),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // Основной контент — в одной сетке с секциями ниже (20px)
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Аватар + имя
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Аватар — тотем шамана
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PiligrimColors.steppe.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        color: PiligrimColors.earthDeep,
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.steppe.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/shaman.svg',
                          width: 30,
                          height: 30,
                          colorFilter: ColorFilter.mode(
                            PiligrimColors.steppe.withValues(alpha: 0.85),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorized
                                ? widget.user.name
                                : 'Герой без имени',
                            style: PiligrimTextStyles.heading.copyWith(
                              fontSize: 18,
                              color: PiligrimColors.sky,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            authorized
                                ? widget.user.phone
                                : 'Войдите, чтобы открыть путь',
                            style: PiligrimTextStyles.caption.copyWith(
                              color: authorized
                                  ? PiligrimColors.water.withValues(alpha: 0.7)
                                  : PiligrimColors.steppe.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 700.ms)
                    .slideX(begin: 0.05, end: 0, duration: 700.ms),

                const SizedBox(height: 16),

                // Плашка начала пути
                if (authorized && widget.user.journeyStartLabel != null)
                  _JourneyTag(label: 'Путь начат: ${widget.user.journeyStartLabel}'),
                if (!authorized)
                  PiligrimTap(
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.onStartJourney,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PiligrimColors.steppe.withValues(alpha: 0.25),
                            PiligrimColors.steppe.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: PiligrimColors.steppe.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'НАЧАТЬ ПУТЬ',
                        style: PiligrimTextStyles.button.copyWith(
                          color: PiligrimColors.steppe,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

// Плашка «Путь начат» — показывает дату, когда гость начал взаимодействие с рестораном
class _JourneyTag extends StatelessWidget {
  const _JourneyTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
            color: PiligrimColors.water.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
        color: PiligrimColors.water.withValues(alpha: 0.06),
      ),
      child: Text(
        label.toUpperCase(),
        style: PiligrimTextStyles.caption.copyWith(
          color: PiligrimColors.water.withValues(alpha: 0.7),
          letterSpacing: 1.8,
          fontSize: 9.5,
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final HeroUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          value: '${user.bookingsCount}',
          label: 'Бронирований',
          totemAsset: 'assets/images/moon_totem (1).svg',
          delay: 0.ms,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${user.eventsCount}',
          label: 'Мероприятий',
          totemAsset: 'assets/images/tree_totem (1).svg',
          delay: 80.ms,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: user.journeyStartLabel ?? '—',
          label: 'С нами',
          totemAsset: 'assets/images/star_totem (1).svg',
          delay: 160.ms,
          small: true,
        ),
      ],
    );
  }
}

// Одна карточка статистики героя (число бронирований, мероприятий и т.д.)
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.totemAsset,
    required this.delay,
    this.small = false,
  });

  final String value;
  final String label;
  final String totemAsset;
  final Duration delay;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PiligrimColors.divider),
          boxShadow: [
            BoxShadow(
              color: PiligrimColors.shadow.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -6,
              bottom: -6,
              child: SvgPicture.asset(
                totemAsset,
                width: 36,
                height: 36,
                colorFilter: ColorFilter.mode(
                  PiligrimColors.water.withValues(alpha: 0.05),
                  BlendMode.srcIn,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: PiligrimTextStyles.heading.copyWith(
                    fontSize: small ? 14 : 20,
                    color: PiligrimColors.water,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: PiligrimTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      )
          .animate(delay: delay)
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.06, end: 0, duration: 500.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.state,
    required this.onToggle,
  });

  final Map<String, bool> state;
  final void Function(String id, bool val) onToggle;

  @override
  Widget build(BuildContext context) {
    return _BrandCard(
      child: Column(
        children: kNotifCategories.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final isOn = state[cat.id] ?? false;
          return Column(
            children: [
              _NotifRow(
                category: cat,
                isOn: isOn,
                onChanged: (val) => onToggle(cat.id, val),
              ),
              if (i < kNotifCategories.length - 1)
                const Divider(
                  height: 1,
                  color: PiligrimColors.divider,
                  indent: 48,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// Строка настройки одного типа уведомлений (вкл/выкл переключатель)
class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.category,
    required this.isOn,
    required this.onChanged,
  });

  final NotifCategory category;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SvgPicture.asset(
            category.iconAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isOn
                  ? PiligrimColors.water
                  : PiligrimColors.sky.withValues(alpha: 0.25),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 14,
                    color: isOn
                        ? PiligrimColors.sky
                        : PiligrimColors.sky.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  category.subtitle,
                  style: PiligrimTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // Брендовый toggle
          GestureDetector(
            onTap: () => onChanged(!isOn),
            child: AnimatedContainer(
              duration: 250.ms,
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isOn
                    ? PiligrimColors.water.withValues(alpha: 0.3)
                    : PiligrimColors.sky.withValues(alpha: 0.06),
                border: Border.all(
                  color: isOn
                      ? PiligrimColors.water.withValues(alpha: 0.7)
                      : PiligrimColors.sky.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: AnimatedAlign(
                duration: 250.ms,
                curve: Curves.easeInOut,
                alignment:
                    isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? PiligrimColors.water
                        : PiligrimColors.sky.withValues(alpha: 0.25),
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color:
                                  PiligrimColors.water.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.onLaunch});
  final Future<void> Function(String url) onLaunch;

  @override
  Widget build(BuildContext context) {
    return _BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Адрес
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  'assets/images/splash_path (1).svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.steppe,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    kRestaurantAddress,
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 13,
                      color: PiligrimColors.sky.withValues(alpha: 0.75),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Кнопки карт
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: kMapTargets.map((t) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t == kMapTargets.last ? 0 : 8,
                    ),
                    child: PiligrimTap(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onLaunch(t.url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: PiligrimColors.steppe.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: PiligrimColors.steppe.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            SvgPicture.asset(
                              t.totemAsset,
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                PiligrimColors.steppe,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t.label,
                              style: PiligrimTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: PiligrimColors.steppe.withValues(alpha: 0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1, color: PiligrimColors.divider),

          // Телефон
          PiligrimTap(
            onTap: () => onLaunch('tel:$kRestaurantPhone'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/cobyz.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.water.withValues(alpha: 0.7),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    kRestaurantPhone,
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 14,
                      color: PiligrimColors.water,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '→',
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 14,
                      color: PiligrimColors.water.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: PiligrimColors.divider),

          // Мессенджеры
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Написать нам',
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: PiligrimColors.sky.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: kMessengers.map((m) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: m == kMessengers.last ? 0 : 10,
                        ),
                        child: PiligrimTap(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onLaunch(m.url),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: m.color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              children: [
                                SvgPicture.asset(
                                  m.totemAsset,
                                  width: 22,
                                  height: 22,
                                  colorFilter: ColorFilter.mode(
                                    m.color,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.label,
                                  style: PiligrimTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: m.color.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 600.ms)
        .slideY(begin: 0.05, end: 0, duration: 600.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOURS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HoursCard extends StatefulWidget {
  @override
  State<_HoursCard> createState() => _HoursCardState();
}

class _HoursCardState extends State<_HoursCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<CoreInfoProvider>();
    final open = core.isOpenNow;
    if (open) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    } else if (_pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
    final hoursText = core.workingHoursNote?.isNotEmpty == true
        ? '${core.workingHoursDisplay}\n${core.workingHoursNote}'
        : core.workingHoursDisplay;
    return _BrandCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Пульс
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final dot = open ? PiligrimColors.water : PiligrimColors.sky.withValues(alpha: 0.18);
                return Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot,
                    boxShadow: open
                        ? [
                            BoxShadow(
                              color: dot.withValues(
                                  alpha: 0.3 + _pulseCtrl.value * 0.4),
                              blurRadius: 4 + _pulseCtrl.value * 8,
                              spreadRadius: _pulseCtrl.value * 3,
                            ),
                          ]
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? 'Открыто сейчас' : 'Закрыто',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 15,
                    color: open ? PiligrimColors.water : PiligrimColors.sky.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hoursText,
                  style: PiligrimTextStyles.caption,
                ),
              ],
            ),
            const Spacer(),
            SvgPicture.asset(
              'assets/images/sun.svg',
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                PiligrimColors.steppe.withValues(alpha: open ? 0.35 : 0.07),
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RULES CARD — раскрываемые пункты
// ─────────────────────────────────────────────────────────────────────────────
class _RulesCard extends StatefulWidget {
  @override
  State<_RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends State<_RulesCard> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    return _BrandCard(
      child: Column(
        children: kVisitRules.asMap().entries.map((entry) {
          final i = entry.key;
          final rule = entry.value;
          final isOpen = _expanded == i;

          return Column(
            children: [
              PiligrimTap(
                onTap: () =>
                    setState(() => _expanded = isOpen ? null : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        rule.iconAsset,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          isOpen
                              ? PiligrimColors.water
                              : PiligrimColors.sky.withValues(alpha: 0.3),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        rule.title,
                        style: PiligrimTextStyles.body.copyWith(
                          fontSize: 14,
                          color: isOpen
                              ? PiligrimColors.sky
                              : PiligrimColors.sky.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: isOpen ? 0.25 : 0,
                        duration: 250.ms,
                        child: Text(
                          '›',
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 20,
                            color: isOpen
                                ? PiligrimColors.water
                                : PiligrimColors.sky.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: 280.ms,
                curve: Curves.easeInOut,
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(46, 0, 16, 16),
                        child: Text(
                          rule.body,
                          style: PiligrimTextStyles.body.copyWith(
                            fontSize: 13,
                            color: PiligrimColors.sky.withValues(alpha: 0.5),
                            height: 1.6,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (i < kVisitRules.length - 1)
                const Divider(
                  height: 1,
                  color: PiligrimColors.divider,
                  indent: 46,
                ),
            ],
          );
        }).toList(),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGAL FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onLaunch});
  final Future<void> Function(String url) onLaunch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Центральный тотем-разделитель
        Center(
          child: SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              PiligrimColors.water.withValues(alpha: 0.2),
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),

        _BrandCard(
          child: Column(
            children: [
              _LegalRow(
                label: 'Пользовательское соглашение',
                onTap: () => onLaunch('https://piligrim.kz/terms'),
              ),
              const Divider(height: 1, color: PiligrimColors.divider, indent: 16),
              _LegalRow(
                label: 'Политика конфиденциальности',
                onTap: () => onLaunch('https://piligrim.kz/privacy'),
              ),
              const Divider(height: 1, color: PiligrimColors.divider, indent: 16),
              _LegalRow(
                label: 'Обратная связь',
                accent: true,
                onTap: () => onLaunch('mailto:hello@piligrim.kz'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Версия + лого
        Column(
          children: [
            SvgPicture.asset(
              'assets/images/piligrim.svg',
              height: 18,
              colorFilter: ColorFilter.mode(
                PiligrimColors.sky.withValues(alpha: 0.12),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Версия $kRestaurantVersion',
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.18),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    )
        .animate()
        .fadeIn(delay: 250.ms, duration: 600.ms);
  }
}

// Строка с юридической ссылкой (соглашение, политика, обратная связь)
class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.label,
    required this.onTap,
    this.accent = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                color: accent
                    ? PiligrimColors.water.withValues(alpha: 0.75)
                    : PiligrimColors.sky.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            Text(
              '›',
              style: PiligrimTextStyles.heading.copyWith(
                fontSize: 16,
                color: PiligrimColors.sky.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: Brand Card + Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PiligrimColors.divider),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.shadow.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

// _SectionHeader заменён на PiligrimSectionHeader (lib/widgets/piligrim_section_header.dart)
