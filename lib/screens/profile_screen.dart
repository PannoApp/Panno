// Экран Профиль / Контакты — «Карта Героя»
// Согласно ТЗ раздел 4.5 | Luxury member lounge · cinematic glass
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

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
import '../widgets/piligrim_delete_account_dialog.dart';
import '../widgets/piligrim_section_header.dart';
import '../widgets/piligrim_tap.dart';
import '../core/piligrim_route.dart';
import '../widgets/piligrim_auth_view.dart';
import 'booking_history_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

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

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showPiligrimDeleteAccountDialog(context);

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthProvider>().deleteAccount();
    } catch (_) {
      if (!mounted) return;
      final message =
          context.read<AuthProvider>().error ?? 'Не удалось удалить аккаунт';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PiligrimColors.earthDeep,
          content: Text(
            message,
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
        if (!auth.isLoggedIn) {
          return PiligrimAuthView(
            onSuccess: (isNewUser) {
              if (isNewUser) {
                auth.clearNewUserFlag();
                Navigator.of(context).push(
                  PiligrimPageRoute(builder: (_) => const OnboardingScreen()),
                );
              }
              context.read<BookingProvider>().loadHistory();
            },
          );
        }
        final user = auth.user;
        final bottomPad = MediaQuery.paddingOf(context).bottom + 32;
        return Scaffold(
          backgroundColor: PiligrimColors.earthSurface,
          body: Stack(
            children: [
              const Positioned.fill(
                child: PiligrimBackground(
                  textureOpacity: 0.38,
                  vignetteIntensity: 0.18,
                  cinematic: true,
                ),
              ),
              const Positioned.fill(child: _ProfileAtmosphere()),
              CustomScrollView(
                physics: null,
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
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (user.isAuthorized) ...[
                          _StatsRow(
                            user: user,
                            onNavigate: widget.onNavigate,
                          ),
                          const SizedBox(height: 28),
                        ],

                    // Push-уведомления
                    const PiligrimSectionHeader(
                      label: 'УВЕДОМЛЕНИЯ',
                      icon: 'assets/images/star_totem (1).svg',
                    ),
                    const SizedBox(height: 14),
                    _NotificationsCard(
                      enabled: auth.isLoggedIn,
                      globalEnabled:
                          auth.currentUser?.notificationsEnabled ?? true,
                      isOn: (id) => _notifValue(auth, id),
                      onToggle: _handleNotifToggle,
                    ),
                    const SizedBox(height: 28),

                    // Контакты
                    const PiligrimSectionHeader(
                      label: 'КОНТАКТЫ',
                      icon: 'assets/images/bird_totem (1).svg',
                    ),
                    const SizedBox(height: 14),
                    _ContactsCard(
                      coreInfo: coreInfo,
                      onLaunch: _launch,
                    ),
                    const SizedBox(height: 28),

                    // Правила посещения
                    const PiligrimSectionHeader(
                      label: 'ПРАВИЛА ПОСЕЩЕНИЯ',
                      icon: 'assets/images/shaman.svg',
                    ),
                    const SizedBox(height: 14),
                    _RulesCard(
                      rules: coreInfo?.visitRules.isNotEmpty == true
                          ? coreInfo!.visitRules
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // Выход и удаление аккаунта
                        if (auth.isLoggedIn) ...[
                          _AccountSessionCard(
                            onLogout: () async {
                              await context.read<AuthProvider>().logout();
                            },
                            onDeleteAccount: _confirmDeleteAccount,
                          ),
                          const SizedBox(height: 28),
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
      height: 152 + top,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Мягкий amber glow — depth через свет, без декоративных тотемов
          // Overflow увеличен до 120px: при -56 нижняя граница DecoratedBox
          // совпадала с последней строкой "Бронирований" (header+56 = card+56),
          // что давало 1px артефакт на Android. Градиент к тому моменту уже
          // clear, поэтому визуально разницы нет.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: -120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.07),
                    PiligrimColors.steppe.withValues(alpha: 0.05),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            top: top - 60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PiligrimColors.steppe.withValues(alpha: 0.14),
                      PiligrimColors.clear,
                    ],
                  ),
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
                PiligrimTap(
                  onTap: () async {
                    if (authorized) {
                      await Navigator.of(context).push(
                        PiligrimPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authorized
                                    ? (widget.user.name.isEmpty ||
                                            widget.user.name == widget.user.phone
                                        ? 'Заполнить имя и фамилию'
                                        : widget.user.phone)
                                    : 'Войдите, чтобы открыть путь',
                                style: PiligrimTextStyles.caption.copyWith(
                                  color: authorized
                                      ? PiligrimColors.steppe.withValues(alpha: 0.7)
                                      : PiligrimColors.steppe.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

// Плашка «Путь начат» — показывает дату, когда герой начал взаимодействие с рестораном
class _JourneyTag extends StatelessWidget {
  const _JourneyTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
            color: PiligrimColors.steppe.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(4),
        color: PiligrimColors.steppe.withValues(alpha: 0.05),
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
  const _StatsRow({required this.user, this.onNavigate});
  final HeroUser user;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final bookingsCount = context.watch<BookingProvider>().history.length;

    return Row(
      children: [
        _StatCard(
          value: '$bookingsCount',
          label: 'Бронирований',
          delay: 0.ms,
          onTap: () => Navigator.of(context).push(
            PiligrimPageRoute(
              builder: (_) => const BookingHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StatCard(
          value: '${user.eventsCount}',
          label: 'Мероприятия',
          delay: 80.ms,
          onTap: () => onNavigate?.call(3),
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
        child: _ProfileGlassCard(
          variant: ProfileGlassVariant.stat,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: PiligrimTextStyles.heading.copyWith(
                    fontSize: 20,
                    color: PiligrimColors.steppe,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: PiligrimTextStyles.caption.copyWith(fontSize: 10),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
      return _ProfileGlassCard(
        variant: ProfileGlassVariant.settings,
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

    return _ProfileGlassCard(
      variant: ProfileGlassVariant.settings,
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
          const _ProfileHairlineDivider(),
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
                      const _ProfileHairlineDivider(),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                        : PiligrimColors.sky.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.subtitle,
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: PiligrimColors.sky.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // iOS-style toggle — тихий, без gaming glow
          PiligrimTap(
            onTap: onChanged != null ? () => onChanged!(!isOn) : null,
            child: AnimatedContainer(
              duration: 250.ms,
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isOn
                    ? PiligrimColors.steppe.withValues(alpha: 0.32)
                    : PiligrimColors.sky.withValues(alpha: 0.08),
                border: Border.all(
                  color: isOn
                      ? PiligrimColors.steppe.withValues(alpha: 0.45)
                      : PiligrimColors.sky.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
              child: AnimatedAlign(
                duration: 250.ms,
                curve: Curves.easeInOut,
                alignment:
                    isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? PiligrimColors.nomadCream
                        : PiligrimColors.sky.withValues(alpha: 0.35),
                    boxShadow: [
                      BoxShadow(
                        color: PiligrimColors.shadow.withValues(
                          alpha: isOn ? 0.22 : 0.12,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                PiligrimColors.steppe.withValues(alpha: 0.65),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13,
                color: PiligrimColors.sky.withValues(alpha: 0.68),
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

    return _ProfileGlassCard(
      variant: ProfileGlassVariant.integrated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Адрес
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
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
                            color: PiligrimColors.steppe.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: PiligrimColors.steppe.withValues(alpha: 0.16),
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

          const _ProfileHairlineDivider(inset: 18),

          // Телефон
          PiligrimTap(
            onTap: () => onLaunch('tel:$phone'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

          const _ProfileHairlineDivider(inset: 18),

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
                rows.add(const _ProfileHairlineDivider(inset: 48));
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
    return _ProfileGlassCard(
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
                const _ProfileHairlineDivider(inset: 18),
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
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PiligrimColors.clear,
                PiligrimColors.steppe.withValues(alpha: 0.22),
                PiligrimColors.clear,
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _ProfileGlassCard(
          variant: ProfileGlassVariant.integrated,
          child: Column(
            children: [
              if (coreInfo?.termsOfService != null) ...[
                _LegalRow(
                  label: 'Пользовательское соглашение',
                  onTap: () => onLaunch(coreInfo!.termsOfService!),
                ),
                const _ProfileHairlineDivider(inset: 18),
              ],
              _LegalRow(
                label: 'Политика конфиденциальности',
                onTap: () => onLaunch(privacy),
              ),
              if (coreInfo?.feedbackUrl != null) ...[
                const _ProfileHairlineDivider(inset: 18),
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

/// Выход и удаление — одна glass-карта, общая сетка отступов (18×14).
class _AccountSessionCard extends StatelessWidget {
  const _AccountSessionCard({
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  static const _rowPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

  @override
  Widget build(BuildContext context) {
    return _ProfileGlassCard(
      variant: ProfileGlassVariant.integrated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PiligrimTap(
            borderRadius: BorderRadius.circular(PiligrimRadius.md),
            onTap: onLogout,
            child: Padding(
              padding: _rowPadding,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выйти из аккаунта',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: PiligrimColors.ember.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ),
          ),
          const _ProfileHairlineDivider(inset: 18),
          PiligrimTap(
            borderRadius: BorderRadius.circular(PiligrimRadius.md),
            onTap: onDeleteAccount,
            child: Padding(
              padding: _rowPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Удалить аккаунт',
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.25,
                      color: PiligrimColors.ember.withValues(alpha: 0.74),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Данные профиля и история будут удалены без возможности восстановления.',
                    style: PiligrimTextStyles.caption.copyWith(
                      fontSize: 11,
                      height: 1.45,
                      letterSpacing: 0.15,
                      color: PiligrimColors.sky.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
// LUXURY ATMOSPHERE + GLASS SURFACES
// ─────────────────────────────────────────────────────────────────────────────

enum ProfileGlassVariant { panel, settings, stat, integrated }

/// Кинематографичный оверлей: amber glow, дымчатый gradient, без декора.
class _ProfileAtmosphere extends StatelessWidget {
  const _ProfileAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  PiligrimColors.ember.withValues(alpha: 0.05),
                  PiligrimColors.earthWarm.withValues(alpha: 0.09),
                  PiligrimColors.earthSurface.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: MediaQuery.sizeOf(context).height * 0.20,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.steppe.withValues(alpha: 0.10),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            bottom: MediaQuery.sizeOf(context).height * 0.18,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PiligrimColors.ember.withValues(alpha: 0.07),
                    PiligrimColors.clear,
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.5, -0.2),
                radius: 1.1,
                colors: [
                  PiligrimColors.clear,
                  PiligrimColors.shadow.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHairlineDivider extends StatelessWidget {
  const _ProfileHairlineDivider({this.inset = 0});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: Container(
        height: 0.5,
        color: PiligrimColors.sky.withValues(alpha: 0.10),
      ),
    );
  }
}

class _ProfileGlassCard extends StatelessWidget {
  const _ProfileGlassCard({
    required this.child,
    this.variant = ProfileGlassVariant.panel,
    this.padding,
  });

  final Widget child;
  final ProfileGlassVariant variant;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      variant == ProfileGlassVariant.stat ? 14 : PiligrimRadius.md,
    );

    // Blur рендерится корректно только на iOS.
    // На Android BackdropFilter даёт артефакты и лаги при скролле.
    final bool useBlur = defaultTargetPlatform == TargetPlatform.iOS;

    final (fillTop, fillBottom, borderAlpha, blurSigma, shadowAlpha) =
        switch (variant) {
      ProfileGlassVariant.stat => (
          0.10,
          0.04,
          0.14,
          10.0,
          0.10,
        ),
      ProfileGlassVariant.settings => (
          0.10,
          0.04,
          0.14,
          14.0,
          0.10,
        ),
      ProfileGlassVariant.integrated => (
          0.08,
          0.03,
          0.10,
          8.0,
          0.06,
        ),
      ProfileGlassVariant.panel => (
          0.12,
          0.05,
          0.12,
          12.0,
          0.12,
        ),
    };

    // На Android увеличиваем непрозрачность заливки, чтобы карточки
    // читались без блюра.
    final double effectiveFillTop    = useBlur ? fillTop    : fillTop    * 2.0;
    final double effectiveFillBottom = useBlur ? fillBottom : fillBottom * 2.0;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PiligrimColors.earthWarm.withValues(alpha: effectiveFillTop),
            PiligrimColors.earth.withValues(alpha: effectiveFillBottom),
          ],
        ),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: borderAlpha),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.steppe.withValues(alpha: shadowAlpha * 0.5),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          if (variant == ProfileGlassVariant.stat ||
              variant == ProfileGlassVariant.settings)
            BoxShadow(
              color: PiligrimColors.ember.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: -4,
            ),
        ],
      ),
      child: child,
    );

    // `integrated` — блюр не применялся и раньше, ветка не меняется.
    if (variant == ProfileGlassVariant.integrated) {
      return ClipRRect(borderRadius: radius, child: content);
    }

    // iOS: glassmorphism с BackdropFilter.
    // Android: твёрдая карточка без блюра (нет артефактов при скролле).
    if (useBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    return ClipRRect(borderRadius: radius, child: content);
  }
}

// _SectionHeader заменён на PiligrimSectionHeader (lib/widgets/piligrim_section_header.dart)

