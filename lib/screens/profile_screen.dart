// Экран Профиль / Контакты — «Карта Героя»
// Согласно ТЗ раздел 4.5 | Luxury member lounge · cinematic glass
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import 'package:cached_network_image/cached_network_image.dart';
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
import '../widgets/path_cta.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_delete_account_dialog.dart';
import '../widgets/piligrim_toast.dart';
import '../widgets/piligrim_section_header.dart';
import '../widgets/piligrim_tap.dart';
import '../core/piligrim_route.dart';
import '../widgets/piligrim_auth_view.dart';
import 'booking_history_screen.dart';
import 'event_reservation_history_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // AuthProvider.init() (main.dart) восстанавливает сессию асинхронно и
  // может завершиться позже первого кадра — если на момент этой проверки
  // isLoggedIn ещё false, полагаемся на повторную проверку в build()
  // (см. Consumer<AuthProvider> ниже), чтобы история всё равно подгрузилась,
  // когда авторизация восстановится.
  bool _historyRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().isLoggedIn) {
        _historyRequested = true;
        context.read<BookingProvider>().loadHistory();
      }
    });
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
      PiligrimToast.show(
        context,
        message,
        type: PiligrimToastType.error,
      );
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        PiligrimToast.show(
          context,
          'Не удалось открыть ссылку',
          type: PiligrimToastType.error,
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
              _historyRequested = true;
              context.read<BookingProvider>().loadHistory();
            },
          );
        }
        if (!_historyRequested) {
          // Сюда попадаем, когда AuthProvider.init() восстановил сессию уже
          // после первого кадра (см. комментарий у _historyRequested) —
          // initState это пропустил, догоняем здесь.
          _historyRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.read<BookingProvider>().loadHistory();
          });
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
                      isLoggedIn: auth.isLoggedIn,
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
                          const SizedBox(height: 24),
                          const PiligrimSectionHeader(
                            label: 'КАРТА ЛОЯЛЬНОСТИ',
                            icon: 'assets/images/shaman.svg',
                          ),
                          const SizedBox(height: 14),
                          _LoyaltyCard(user: user),
                          const SizedBox(height: 28),
                        ],

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
    required this.isLoggedIn,
    required this.onStartJourney,
  });

  final HeroUser user;
  final bool isLoggedIn;
  final Future<void> Function() onStartJourney;

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader> {

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final hasName = widget.user.name.isNotEmpty &&
        widget.user.name != widget.user.phone;
    final displayName = hasName
        ? widget.user.name.split(' ').first
        : 'Гость';

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
                // Profile header group: имя + карандаш единым блоком
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: PiligrimTextStyles.heading.copyWith(
                            fontSize: 22,
                            color: PiligrimColors.sky,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.isLoggedIn) ...[
                          const SizedBox(width: 6),
                          PiligrimTap(
                            onTap: () async {
                              await Navigator.of(context).push(
                                PiligrimPageRoute(
                                  builder: (_) => const OnboardingScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: PiligrimColors.steppe.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        PiligrimToast.show(
                          context,
                          'Успешно: Настройки сохранены!',
                          type: PiligrimToastType.success,
                        );
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!mounted) return;
                          PiligrimToast.show(
                            context,
                            'Информация: Новое мероприятие добавлено',
                            type: PiligrimToastType.info,
                          );
                        });
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (!mounted) return;
                          PiligrimToast.show(
                            context,
                            'Ошибка: Не удалось обновить профиль',
                            type: PiligrimToastType.error,
                          );
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(
                          'Ваш путь в PILIGRIM',
                          style: PiligrimTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: PiligrimColors.steppe.withValues(alpha: 0.50),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 700.ms)
                    .slideX(begin: 0.05, end: 0, duration: 700.ms),

                const SizedBox(height: 16),

                if (!widget.isLoggedIn)
                  PathCta(
                    label: 'НАЧАТЬ ПУТЬ',
                    onTap: widget.onStartJourney,
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

String _pluralize(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 19) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
// Мероприятия временно скрыты в профиле — фича ещё не готова к показу.
// Вернуть: поставить true.
const bool _showEventsStatCard = false;

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
          label: _pluralize(bookingsCount, 'Бронирование', 'Бронирования', 'Бронирований'),
          delay: 0.ms,
          onTap: () => Navigator.of(context).push(
            PiligrimPageRoute(
              builder: (_) => const BookingHistoryScreen(),
            ),
          ),
        ),
        if (_showEventsStatCard) ...[
          const SizedBox(width: 12),
          _StatCard(
            value: '${user.eventsCount}',
            label: _pluralize(user.eventsCount, 'Мероприятие', 'Мероприятия', 'Мероприятий'),
            delay: 80.ms,
            onTap: () => Navigator.of(context).push(
              PiligrimPageRoute(
                builder: (_) => const EventReservationHistoryScreen(),
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        _StatCard(
          value: user.journeyStartValue ?? '—',
          label: user.journeyStartLabel ?? 'С нами',
          delay: 160.ms,
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
    this.onTap,
  });

  final String value;
  final String label;
  final Duration delay;
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
// LOYALTY CARD — карта лояльности: баланс, % кешбэка и QR из Remarked CRM
// ─────────────────────────────────────────────────────────────────────────────
String _formatCashback(double value) => value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );

/// Матрица `ColorFilter`, перекрашивающая ч/б-растр (0 → [dark], 255 → [light])
/// в два цвета бренда. Работает по значению R-канала входного пикселя, поэтому
/// годится только для действительно серых/ч-б изображений (QR из Remarked —
/// именно такой). Контраст между [dark] и [light] сохраняется, что важно для
/// читаемости кода сканером на кассе.
List<double> _duotoneMatrix({required int darkHex, required int lightHex}) {
  double channel(int hex, int shift) => ((hex >> shift) & 0xFF).toDouble();
  final dr = channel(darkHex, 16), dg = channel(darkHex, 8), db = channel(darkHex, 0);
  final lr = channel(lightHex, 16), lg = channel(lightHex, 8), lb = channel(lightHex, 0);
  final sr = (lr - dr) / 255, sg = (lg - dg) / 255, sb = (lb - db) / 255;
  return [
    sr, 0, 0, 0, dr,
    sg, 0, 0, 0, dg,
    sb, 0, 0, 0, db,
    0, 0, 0, 1, 0,
  ];
}

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.user});
  final HeroUser user;

  @override
  Widget build(BuildContext context) {
    final hasCode = user.loyaltyCardUrl?.isNotEmpty == true;

    return _ProfileGlassCard(
      variant: ProfileGlassVariant.panel,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('БАЛАНС', style: PiligrimTextStyles.sectionLabel),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatCashback(user.cashback)} ₸',
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 16,
                      color: PiligrimColors.steppe,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('КЕШБЭК', style: PiligrimTextStyles.sectionLabel),
                  const SizedBox(height: 3),
                  Text(
                    user.loyaltyPercent ?? '—',
                    style: PiligrimTextStyles.heading.copyWith(
                      fontSize: 16,
                      color: PiligrimColors.steppe,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: hasCode
                ? _LoyaltyQrTile(url: user.loyaltyCardUrl!)
                : const _LoyaltyQrPlaceholder(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              hasCode ? 'Покажите QR-код на кассе' : 'Появится после первого визита',
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                color: PiligrimColors.steppe.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06, end: 0, duration: 500.ms);
  }
}

/// QR карты лояльности — картинка приходит готовой из Remarked (ч/б PNG).
///
/// Сами модули кода намеренно остаются близко к тёмно-нейтральному цвету
/// ([PiligrimColors.textDark] на [PiligrimColors.nomadCream]) — это вопрос
/// надёжности сканирования на кассе, не эстетики: сильно окрашивать пиксели
/// кода в яркий акцент бренда рискованно (снижает контраст, скан может не
/// сработать в плохом освещении зала). Поэтому «бренд» несёт не сам код,
/// а рамка вокруг него — градиентная окантовка ember→steppe и тёплое
/// свечение под плиткой, в духе остальных акцентных карточек этого экрана.
class _LoyaltyQrTile extends StatelessWidget {
  const _LoyaltyQrTile({required this.url});
  final String url;

  static const double _size = 148;
  static const double _borderWidth = 2.5;

  static final List<double> _tint = _duotoneMatrix(
    darkHex: 0x2C2825, // PiligrimColors.textDark
    lightHex: 0xF2ECE1, // PiligrimColors.nomadCream
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_borderWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PiligrimRadius.md + _borderWidth),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PiligrimColors.steppe, PiligrimColors.emberDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.steppe.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: PiligrimColors.nomadCream,
          borderRadius: PiligrimRadius.mdAll,
        ),
        child: CachedNetworkImage(
          imageUrl: url,
          width: _size,
          height: _size,
          fit: BoxFit.contain,
          imageBuilder: (context, imageProvider) => ColorFiltered(
            colorFilter: ColorFilter.matrix(_tint),
            child: Image(
              image: imageProvider,
              width: _size,
              height: _size,
              fit: BoxFit.contain,
            ),
          ),
          placeholder: (context, _) => const SizedBox(
            width: _size,
            height: _size,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PiligrimColors.textDark,
                ),
              ),
            ),
          ),
          errorWidget: (context, _, __) => SizedBox(
            width: _size,
            height: _size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 28,
                  color: PiligrimColors.textDark.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 6),
                Text(
                  'Не удалось загрузить QR',
                  textAlign: TextAlign.center,
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: PiligrimColors.textDark.withValues(alpha: 0.5),
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

/// Показывается, пока у гостя ещё нет карты/QR в Remarked (первая синхронизация
/// ещё не произошла или гость только что зарегистрирован). Пунктирная рамка
/// вместо градиентной — визуально читается как «неактивно», в отличие от
/// «живой» карты в [_LoyaltyQrTile].
class _LoyaltyQrPlaceholder extends StatelessWidget {
  const _LoyaltyQrPlaceholder();

  @override
  Widget build(BuildContext context) {
    const size = _LoyaltyQrTile._size + _LoyaltyQrTile._borderWidth * 2 + 24;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PiligrimColors.nomadCream.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(PiligrimRadius.md + _LoyaltyQrTile._borderWidth),
        border: Border.all(
          color: PiligrimColors.steppe.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 32,
            color: PiligrimColors.steppe.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Карта появится после первого визита',
            textAlign: TextAlign.center,
            style: PiligrimTextStyles.caption.copyWith(fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Маппинг названия мессенджера → SVG-ассет (для социальных ссылок с бэкенда)
String _resolveMessengerIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('whatsapp')) return 'assets/images/whatsapp_generic.svg';
  if (l.contains('telegram')) return 'assets/images/telegram_generic.svg';
  if (l.contains('instagram')) return 'assets/images/instagram_generic.svg';
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
                color: PiligrimColors.steppe.withValues(alpha: 0.82),
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
    final phone = coreInfo?.phone.isNotEmpty == true
        ? coreInfo!.phone
        : kRestaurantPhone;
    // Карта — только 2ГИС (основной картографический сервис для аудитории РК)
    final mapLinks = [
      if (coreInfo?.twogisLink != null)
        (label: '2ГИС', icon: 'assets/images/map_pin_generic.svg', url: coreInfo!.twogisLink!),
    ];
    final address = coreInfo?.address ?? '';

    final messengers = coreInfo?.socialLinks.isNotEmpty == true
        ? coreInfo!.socialLinks
        : null;

    return _ProfileGlassCard(
      variant: ProfileGlassVariant.integrated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      fontSize: 13,
                      color: PiligrimColors.steppe.withValues(alpha: 0.82),
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

          // Адрес + карта — в самом низу карточки
          if (address.isNotEmpty || mapLinks.isNotEmpty) ...[
            const _ProfileHairlineDivider(inset: 18),

            // Адрес — показываем только если пришёл непустым с бэкенда
            if (address.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, mapLinks.isNotEmpty ? 10 : 18),
                child: Text(
                  'Наш адрес: $address',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 13,
                    color: PiligrimColors.steppe.withValues(alpha: 0.82),
                  ),
                ),
              ),

            // Кнопка 2ГИС — скрываем если ссылка null
            if (mapLinks.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(18, address.isNotEmpty ? 0 : 18, 18, 18),
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
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 600.ms)
        .slideY(begin: 0.05, end: 0, duration: 600.ms);
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
            onTap: () {
              debugPrint('[PiligrimToastTest] Tapped test button');
              PiligrimToast.show(
                context,
                'Успешно: Тестовый тост!',
                type: PiligrimToastType.success,
              );
              Future.delayed(const Duration(milliseconds: 400), () {
                PiligrimToast.show(
                  context,
                  'Информация: Новое сообщение',
                  type: PiligrimToastType.info,
                );
              });
              Future.delayed(const Duration(milliseconds: 800), () {
                PiligrimToast.show(
                  context,
                  'Ошибка: Соединение прервано',
                  type: PiligrimToastType.error,
                );
              });
            },
            child: Padding(
              padding: _rowPadding,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Проверить тосты (тест)',
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: PiligrimColors.steppe,
                  ),
                ),
              ),
            ),
          ),
          const _ProfileHairlineDivider(inset: 18),
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
                    color: PiligrimColors.fruit.withValues(alpha: 0.86),
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
                      letterSpacing: 0.25,
                      color: PiligrimColors.fruit.withValues(alpha: 0.74),
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

