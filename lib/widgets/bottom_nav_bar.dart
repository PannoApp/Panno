// PILIGRIM — встроенный нижний футер (не плавающий док). На всю ширину, у края safe area.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

const Color _kNavActive = PiligrimColors.water;
// Тёплый янтарный песок — отсылка к Сары дала (жёлтой степи) палитры PILIGRIM.
// На тёмном фоне читается как живой, тёплый оттенок, а не серый disabled.
const Color _kNavInactive = Color(0xA0C4A880);

const Duration _kDur   = Duration(milliseconds: 350);
const Curve    _kCurve = Curves.easeInOutCubic;

class PiligrimNavBar extends StatelessWidget {
  const PiligrimNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(label: 'Главная',  asset: 'assets/images/star_totem (1).svg'),
    _NavItem(label: 'Меню',     asset: 'assets/images/bird_totem (1).svg'),
    _NavItem(label: 'Интерьер', asset: 'assets/images/wheel_totem (1).svg'),
    _NavItem(label: 'Афиша',    asset: 'assets/images/tree_totem (1).svg'),
    _NavItem(label: 'Профиль',  asset: 'assets/images/shaman.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        // Верх совпадает с earth — граница растворяется.
        // Мягкий тёплый акцент в средней зоне: фон ощущается как материал, не как слой.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF151210),  // = earth — нулевой разрыв с экраном
            Color(0xFF1D1611),  // лёгкий тёплый акцент (−6R от прежнего)
            Color(0xFF161110),  // спокойный земляной
            Color(0xFF0D0B09),  // якорное дно
          ],
          stops: [0.0, 0.32, 0.66, 1.0],
        ),
        boxShadow: PiligrimShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: PiligrimTap(
                  onTap: () => onTap(i),
                  child: _NavTabCell(item: item, active: active),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTabCell extends StatelessWidget {
  const _NavTabCell({required this.item, required this.active});

  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavTotemIcon(asset: item.asset, active: active),
        const SizedBox(height: 5),
        // Подпись — плавный переход цвета и letter-spacing
        AnimatedDefaultTextStyle(
          duration: _kDur,
          curve: _kCurve,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 10,
            height: 1.05,
            color: active ? _kNavActive : _kNavInactive,
            letterSpacing: active ? 0.6 : 0.9,
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTotemIcon extends StatelessWidget {
  const _NavTotemIcon({required this.asset, required this.active});

  final String asset;
  final bool active;

  static const double _sizeActive   = 24.0;
  static const double _sizeInactive = 20.0;
  // Масштаб иконки в неактивном состоянии (относительно активного)
  static const double _inactiveScale = _sizeInactive / _sizeActive;

  @override
  Widget build(BuildContext context) {
    final isHeavyGlyph = asset.contains('moon') || asset.contains('shaman');
    final renderSize = _sizeActive * (isHeavyGlyph ? 0.88 : 1.0);

    return SizedBox(
      width: 40,
      height: _sizeActive,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow — видим только на активном табе
          if (active)
            IgnorePointer(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PiligrimColors.water.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          // Иконка — плавное масштабирование через AnimatedScale
          AnimatedScale(
            scale: active ? 1.0 : _inactiveScale,
            duration: _kDur,
            curve: _kCurve,
            child: SvgPicture.asset(
              asset,
              width: renderSize,
              height: renderSize,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                active ? _kNavActive : _kNavInactive,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.asset});
  final String label;
  final String asset;
}
