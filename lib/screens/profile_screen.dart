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
import '../data/models/core_info.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/core_info_provider.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_section_header.dart';
import '../widgets/piligrim_tap.dart';
import 'booking_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<BookingProvider>().loadHistory();
      }
    });
  }

  bool _notifValue(AuthProvider auth, String id) {
    final user = auth.currentUser;
    if (user == null) return false;
    return switch (id) {
      'events' => user.notifyEvents,
      'promo' => user.notifyPromotions,
      'private' => user.notifyClosedEvents,
      _ => false,
    };
  }

  Future<void> _handleNotifToggle(String id, bool value) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    try {
      switch (id) {
        case 'global':
          await auth.updateNotificationPreferences(notificationsEnabled: value);
        case 'events':
          await auth.updateNotificationPreferences(events: value);
        case 'promo':
          await auth.updateNotificationPreferences(promotions: value);
        case 'private':
          await auth.updateNotificationPreferences(closedEvents: value);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PiligrimColors.earthDeep,
          content: Text(
            auth.error ?? 'Не удалось сохранить настройки',
            style: PiligrimTextStyles.body.copyWith(fontSize: 13),
          ),
        ),
      );
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: PiligrimColors.earth,
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
    final core = context.watch<CoreInfoProvider>();
    final coreInfo = core.coreInfo;

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
                  cinematic: true,
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
                        if (user.isAuthorized) ...[
                          _StatsRow(user: user),
                          const SizedBox(height: 20),
                        ],

                    // Push-уведомления
                    const PiligrimSectionHeader(
                      label: 'УВЕДОМЛЕНИЯ',
                      icon: 'assets/images/star_totem (1).svg',
                    ),
                    const SizedBox(height: 12),
                    _NotificationsCard(
                      enabled: auth.isLoggedIn,
                      globalEnabled:
                          auth.currentUser?.notificationsEnabled ?? true,
                      isOn: (id) => _notifValue(auth, id),
                      onToggle: _handleNotifToggle,
                    ),
                    const SizedBox(height: 20),

                    // Контакты
                    const PiligrimSectionHeader(
                      label: 'КОНТАКТЫ',
                      icon: 'assets/images/splash_path (1).svg',
                    ),
                    const SizedBox(height: 12),
                    _ContactsCard(
                      coreInfo: coreInfo,
                      onLaunch: _launch,
                    ),
                    const SizedBox(height: 20),

                    // Часы работы
                    const PiligrimSectionHeader(
                      label: 'ЧАСЫ РАБОТЫ',
                      icon: 'assets/images/sun.svg',
                    ),
                    const SizedBox(height: 12),
                    _HoursCard(),
                    const SizedBox(height: 20),

                    // Правила посещения
                    const PiligrimSectionHeader(
                      label: 'ПРАВИЛА ПОСЕЩЕНИЯ',
                      icon: 'assets/images/shaman.svg',
                    ),
                    const SizedBox(height: 12),
                    _RulesCard(
                      rules: coreInfo?.visitRules.isNotEmpty == true
                          ? coreInfo!.visitRules
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Выход из аккаунта
                        if (auth.isLoggedIn) ...[
                          const SizedBox(height: 8),
                          _LogoutButton(
                            onTap: () async {
                              await context.read<AuthProvider>().logout();
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                    // Юридическое + версия
                        _LegalFooter(
                          privacyUrl: coreInfo?.privacyPolicy,
                          coreInfo: coreInfo,
                          onLaunch: _launch,
                        ),
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

class _HeroHeaderState extends State<_HeroHeader> {

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final authorized = widget.user.isAuthorized;

    return SizedBox(
      height: 190 + top,
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

          // Статичный тотем-фон (не вращается — благородство, не игра)
          Positioned(
            right: -50,
            top: top - 30,
            child: SvgPicture.asset(
              'assets/images/wheel_totem (1).svg',
              width: 240,
              height: 240,
              colorFilter: ColorFilter.mode(
                PiligrimColors.steppe.withValues(alpha: 0.10),
                BlendMode.srcIn,
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
                // Имя пользователя — главный типографический акцент
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Декоративный тотем-знак — не аватарка, просто марка
                    SvgPicture.asset(
                      'assets/images/shaman.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        PiligrimColors.steppe.withValues(alpha: 0.55),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorized
                                ? (widget.user.name.isEmpty ||
                                        widget.user.name == widget.user.phone
                                    ? widget.user.phone
                                    : widget.user.name)
                                : 'Герой без имени',
                            style: PiligrimTextStyles.heading.copyWith(
                              fontSize: 22,
                              color: PiligrimColors.sky,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authorized
                                ? (widget.user.name.isEmpty ||
                                        widget.user.name == widget.user.phone
                                    ? 'Герой Piligrim'
                                    : widget.user.phone)
                                : 'Войдите, чтобы открыть путь',
                            style: PiligrimTextStyles.caption.copyWith(
                              color: authorized
                                  ? PiligrimColors.steppe.withValues(alpha: 0.7)
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
            color: PiligrimColors.steppe.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(4),
        color: PiligrimColors.steppe.withValues(alpha: 0.07),
      ),
      child: Text(
        label.toUpperCase(),
        style: PiligrimTextStyles.caption.copyWith(
          color: PiligrimColors.steppe.withValues(alpha: 0.75),
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
    final bookingsCount =
        context.watch<BookingProvider>().history.length;

    if (bookingsCount == 0 && user.eventsCount == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        _StatCard(
          value: '$bookingsCount',
          label: 'Бронирования',
          delay: 0.ms,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BookingHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StatCard(
          value: '${user.eventsCount}',
          label: 'Мероприятия',
          delay: 80.ms,
        ),
        const SizedBox(width: 12),
        _StatCard(
          value: user.journeyStartLabel ?? '—',
          label: 'С нами',
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
    required this.delay,
    this.small = false,
    this.onTap,
  });

  final String value;
  final String label;
  final Duration delay;
  final bool small;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PiligrimTap(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: PiligrimColors.earth,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PiligrimColors.steppe.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: PiligrimColors.shadow.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: PiligrimTextStyles.heading.copyWith(
                  fontSize: small ? 14 : 20,
                  color: PiligrimColors.steppe,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: PiligrimTextStyles.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.06, end: 0, duration: 500.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.enabled,
    required this.globalEnabled,
    required this.isOn,
    required this.onToggle,
  });

  final bool enabled;
  // Глобальный флаг из UserProfile.notificationsEnabled
  final bool globalEnabled;
  final bool Function(String id) isOn;
  final Future<void> Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _BrandCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Войдите, чтобы управлять уведомлениями',
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 13,
              color: PiligrimColors.sky.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    return _BrandCard(
      child: Column(
        children: [
          // Главный переключатель — отражает notifications_enabled с сервера
          _NotifRow(
            category: const NotifCategory(
              id: 'global',
              label: 'Уведомления',
              subtitle: 'Включить все push-уведомления',
              iconAsset: 'assets/images/moon_totem (1).svg',
            ),
            isOn: globalEnabled,
            onChanged: (val) => onToggle('global', val),
          ),
          const Divider(height: 1, color: PiligrimColors.divider, indent: 48),
          // Категории — задизаблены визуально и функционально при globalEnabled=false
          Opacity(
            opacity: globalEnabled ? 1.0 : 0.4,
            child: Column(
              children: kNotifCategories.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                final on = isOn(cat.id);
                return Column(
                  children: [
                    _NotifRow(
                      category: cat,
                      isOn: on,
                      onChanged:
                          globalEnabled ? (val) => onToggle(cat.id, val) : null,
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
          ),
        ],
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
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
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
          PiligrimTap(
            onTap: onChanged != null ? () => onChanged!(!isOn) : null,
            child: AnimatedContainer(
              duration: 250.ms,
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isOn
                    ? PiligrimColors.steppe.withValues(alpha: 0.25)
                    : PiligrimColors.sky.withValues(alpha: 0.06),
                border: Border.all(
                  color: isOn
                      ? PiligrimColors.steppe.withValues(alpha: 0.6)
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
                  margin: const EdgeInsets.all(4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? PiligrimColors.steppe
                        : PiligrimColors.sky.withValues(alpha: 0.25),
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color: PiligrimColors.steppe.withValues(alpha: 0.5),
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

/// Маппинг названия мессенджера → SVG-ассет (для социальных ссылок с бэкенда)
String _resolveMessengerIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('whatsapp')) return 'assets/images/whatsappsvg.svg';
  if (l.contains('telegram')) return 'assets/images/telegramsvg.svg';
  if (l.contains('instagram')) return 'assets/images/instagramsvg.svg';
  return 'assets/images/shaman.svg'; // fallback
}

class _MessengerChip extends StatelessWidget {
  const _MessengerChip({
    required this.label,
    required this.url,
    required this.iconAsset,
    required this.onLaunch,
  });

  final String label;
  final String url;
  final String iconAsset;
  final Future<void> Function(String url) onLaunch;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: () => onLaunch(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                PiligrimColors.steppe.withValues(alpha: 0.75),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                color: PiligrimColors.sky.withValues(alpha: 0.75),
              ),
            ),
            const Spacer(),
            Text(
              '›',
              style: PiligrimTextStyles.heading.copyWith(
                fontSize: 18,
                color: PiligrimColors.steppe.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ContactsCard extends StatelessWidget {
  const _ContactsCard({
    required this.coreInfo,
    required this.onLaunch,
  });

  final CoreInfo? coreInfo;
  final Future<void> Function(String url) onLaunch;

  @override
  Widget build(BuildContext context) {
    final address = coreInfo?.address.isNotEmpty == true
        ? coreInfo!.address
        : kRestaurantAddress;
    final phone = coreInfo?.phone.isNotEmpty == true
        ? coreInfo!.phone
        : kRestaurantPhone;
    // Список карт — только те, у которых есть ссылка из CoreInfo
    final mapLinks = [
      if (coreInfo?.twogisLink != null)
        (label: '2ГИС', icon: 'assets/images/2gis.svg', url: coreInfo!.twogisLink!),
      if (coreInfo?.googleMapsLink != null)
        (label: 'Google', icon: 'assets/images/googlemapssvg.svg', url: coreInfo!.googleMapsLink!),
      if (coreInfo?.yandexMapsLink != null)
        (label: 'Яндекс', icon: 'assets/images/yandexsvg.svg', url: coreInfo!.yandexMapsLink!),
    ];

    final messengers = coreInfo?.socialLinks.isNotEmpty == true
        ? coreInfo!.socialLinks
        : null;

    return _BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Адрес
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              address,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                color: PiligrimColors.sky.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ),

          // Кнопки карт — скрываем если все ссылки null
          if (mapLinks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: mapLinks.map((t) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: t == mapLinks.last ? 0 : 8,
                      ),
                      child: PiligrimTap(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onLaunch(t.url),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: PiligrimColors.steppe.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: PiligrimColors.steppe.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                t.icon,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  PiligrimColors.steppe.withValues(alpha: 0.85),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t.label,
                                style: PiligrimTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: PiligrimColors.steppe.withValues(alpha: 0.75),
                                  letterSpacing: 0.4,
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
            onTap: () => onLaunch('tel:$phone'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/phonesvg.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.steppe.withValues(alpha: 0.7),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    phone,
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 14,
                      color: PiligrimColors.steppe,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '›',
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 18,
                      color: PiligrimColors.steppe.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: PiligrimColors.divider),

          // Мессенджеры — список строк с иконками
          ...() {
            final items = (messengers != null
                ? messengers.map((link) {
                    return _MessengerChip(
                      label: link.label,
                      url: link.url,
                      iconAsset: _resolveMessengerIcon(link.label),
                      onLaunch: onLaunch,
                    );
                  }).toList()
                : kMessengers
                    .map((m) => _MessengerChip(
                          label: m.label,
                          url: m.url,
                          iconAsset: m.iconAsset,
                          onLaunch: onLaunch,
                        ))
                    .toList());
            final List<Widget> rows = [];
            for (int i = 0; i < items.length; i++) {
              rows.add(items[i]);
              if (i < items.length - 1) {
                rows.add(const Divider(
                    height: 1, color: PiligrimColors.divider, indent: 46));
              }
            }
            return rows;
          }(),
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
                final dot = open ? PiligrimColors.ember : PiligrimColors.sky.withValues(alpha: 0.18);
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
                    color: open ? PiligrimColors.ember : PiligrimColors.sky.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
  const _RulesCard({this.rules});

  /// Если null или пусто — fallback на [kVisitRules].
  final List<VisitRuleItem>? rules;

  @override
  State<_RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends State<_RulesCard> {
  int? _expanded;

  List<({String title, String body, String iconAsset})> get _items {
    final api = widget.rules;
    if (api != null && api.isNotEmpty) {
      return api
          .map(
            (r) => (
              title: r.title,
              body: r.body,
              iconAsset: 'assets/images/shaman.svg',
            ),
          )
          .toList();
    }
    return kVisitRules
        .map((r) => (title: r.title, body: r.body, iconAsset: r.iconAsset))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return _BrandCard(
      child: Column(
        children: items.asMap().entries.map((entry) {
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
                                ? PiligrimColors.steppe
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              if (i < items.length - 1)
                const Divider(
                  height: 1,
                  color: PiligrimColors.divider,
                  indent: 16,
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
  const _LegalFooter({
    required this.onLaunch,
    this.privacyUrl,
    this.coreInfo,
  });

  final Future<void> Function(String url) onLaunch;
  final String? privacyUrl;
  final CoreInfo? coreInfo;

  @override
  Widget build(BuildContext context) {
    final privacy = privacyUrl?.isNotEmpty == true
        ? privacyUrl!
        : 'https://piligrim.kz/privacy';

    return Column(
      children: [
        // Центральный тотем-разделитель
        Center(
          child: SvgPicture.asset(
            'assets/images/spiral.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              PiligrimColors.steppe.withValues(alpha: 0.25),
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),

        _BrandCard(
          child: Column(
            children: [
              if (coreInfo?.termsOfService != null) ...[
                _LegalRow(
                  label: 'Пользовательское соглашение',
                  onTap: () => onLaunch(coreInfo!.termsOfService!),
                ),
                const Divider(height: 1, color: PiligrimColors.divider, indent: 16),
              ],
              _LegalRow(
                label: 'Политика конфиденциальности',
                onTap: () => onLaunch(privacy),
              ),
              if (coreInfo?.feedbackUrl != null) ...[
                const Divider(height: 1, color: PiligrimColors.divider, indent: 16),
                _LegalRow(
                  label: 'Обратная связь',
                  accent: true,
                  onTap: () => onLaunch(coreInfo!.feedbackUrl!),
                ),
              ],
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BrandCard(
      child: PiligrimTap(
        borderRadius: BorderRadius.circular(PiligrimRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                'Выйти из аккаунта',
                style: PiligrimTextStyles.body.copyWith(
                  fontSize: 13,
                  color: PiligrimColors.ember.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.logout_rounded,
                size: 16,
                color: PiligrimColors.ember.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
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
                    ? PiligrimColors.steppe.withValues(alpha: 0.85)
                    : PiligrimColors.sky.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            Text(
              '›',
              style: PiligrimTextStyles.heading.copyWith(
                fontSize: 18,
                color: PiligrimColors.steppe.withValues(alpha: 0.25),
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
        color: PiligrimColors.earth,
        borderRadius: BorderRadius.circular(PiligrimRadius.md),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.shadow.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PiligrimRadius.md),
        child: child,
      ),
    );
  }
}

// _SectionHeader заменён на PiligrimSectionHeader (lib/widgets/piligrim_section_header.dart)
